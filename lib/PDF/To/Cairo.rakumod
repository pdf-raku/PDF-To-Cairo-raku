use v6;

class PDF::To::Cairo:ver<0.0.2> {

# A lightweight draft renderer for PDF via Cairo to PNG, SVG, etc
# Aim is preview output for PDF::Content generated PDF's
#
    use PDF::Class;
    use PDF::XObject::Image;
    use Cairo:ver(v0.2.1+);
    use PDF::Content::Canvas;
    use PDF::Content::FontObj;
    use PDF::Content::Ops :OpCode, :TextMode;
    use PDF::Font::Loader;
    use PDF::Font::Loader::Glyph;
    use Font::FreeType::Face;
    use Method::Also;

    constant PDF-LineCaps = PDF::Content::Ops::LineCaps;
    constant PDF-LineJoin = PDF::Content::Ops::LineJoin;

    has PDF::Content::Canvas $.canvas is required handles <width height>; # page, xobject, pattern
    has Cairo::Surface $.surface = Cairo::Image.create(Cairo::FORMAT_ARGB32, self.width, self.height);
    has Cairo::Context $.ctx .= new: $!surface;
    has Cairo::Path $!text-clip;
    has %!current-font;
    has Hash @!gsave;
    has Numeric ($!tx = 0.0, $!ty = 0.0); # text flow
    has Numeric $!hscale = 1.0;
    my class Cache {
        has Lock $!lock handles<protect> .= new;
        has Cairo::Surface %.form{Any};
        has %.pattern{Any};
        has %.font{Any};
        has %.scaled-font{Any};
        has %.color{Any};
    }
    has Cache $.cache .= new;
    has UInt $.nesting = 0;

    submethod TWEAK(
        Bool :$trace,
        :$gfx = $!canvas.gfx(:$trace),
        Bool :$feed = True,
        Bool :$transparent = False,
    ) {
        self!init: :$transparent;
        $gfx.callback.push: self.callback
            if $feed;
    }
    submethod DESTORY {
        .destroy with $!text-clip;
    }

    method render(|c --> Cairo::Surface) {
        my $obj = self.new( :!feed, |c);
        my PDF::Content::Canvas $canvas = $obj.canvas;
        my @callback = [ $obj.callback ];
        if $canvas.has-pre-gfx {
            my $pre-gfx = $canvas.new-gfx: :@callback;
            $pre-gfx.ops: $canvas.pre-gfx.ops;
        }
        temp $canvas.gfx.callback = @callback;
        $canvas.render;
        $obj.surface;
    }

    method !init(:$transparent) {
        my \bbox := $!canvas.bbox;
        $!ctx.translate(-bbox[0], bbox[3]);
        $!ctx.line_width = 1.0;
        unless $transparent {
            $!ctx.rgb(1.0, 1.0, 1.0);
            $!ctx.paint;
        }
    }

    method !coords(Numeric \x, Numeric \y) {
        (x, -y);
    }
    method !set-color($_, $alpha) {
        need PDF::ColorSpace::ICCBased;
        need PDF::ColorSpace::Separation;
        need PDF::ColorSpace::DeviceN;
        need PDF::ColorSpace::CalRGB;
        my constant @CS = [Mu, 'DeviceGray', Mu, 'DeviceRGB', 'DeviceCMYK'];
        my ($cs, $colors) = .kv;
        given $cs {
            when PDF::ColorSpace::ICCBased {
                # nyi. fallback to alternative or raw colors
                with .Alternate // @CS[+$colors] {
                    self!set-color($_ => $colors, $alpha);
                }
            }
            when PDF::ColorSpace::Separation
            |    PDF::ColorSpace::DeviceN {
                # use the Alternative color-space
                with .AlternateSpace -> $alt {
                    $colors := .calculator.calc($colors)
                        with .TintTransform;
                    self!set-color($alt => $colors, $alpha);
                }
            }
            when PDF::ColorSpace::CalRGB {
                my $rgb = $!cache.protect: {
                    $!cache.color{$_} //= do {
                        my \g = .Gamma;
                        my \m = .Matrix;

                        my @abc[3] = $colors.list;
                        @abc **= g[$_] for ^3;
                        # todo white/black point adjustments
                        my @ = (^3).map: {
                            m[$_] * @abc[0]
                            + m[$_ + 3] * @abc[1]
                            + m[$_ + 6] * @abc[2]
                        }
                    }
                }
                self!set-color('DeviceRGB' => $rgb, $alpha);
            }
            when 'DeviceRGB' {
                $!ctx.rgba: |$colors, $alpha;
            }
            when 'DeviceGray' {
                my @rgb = $colors[0] xx 3;
                $!ctx.rgba: |@rgb, $alpha;
            }
            when 'DeviceCMYK' {
                # See [PDF 32000 10.3.5 - Conversion from DeviceCMYK to DeviceRGB]
                my @cmyk = $colors.list;
                my $k = @cmyk.pop;
                my @rgb = @cmyk.map: { 1.0 - min(1.0, $_ + $k) };
                $!ctx.rgba: |@rgb, $alpha;
            }
            when 'Pattern' {
                use PDF::Pattern :PatternTypes;
                with $colors[0] {
                    with $*gfx.resource-entry('Pattern', $_) -> PDF::Pattern $pattern {
                        given $pattern.PatternType {
                            when Tiling {
                                my $img = self!render-tiling-pattern($pattern, $alpha);
                                $!ctx.pattern: $img;
                            }
                            when Shading {
                                warn "can't do type-2 patterns (Shading) yet";
                                Mu;
                            }
                        }
                    }
                }
            }
            when Str {
                with $*gfx.resource-entry('ColorSpace', $_) {
                    self!set-color($_ => $colors, $alpha);
                }
                else {
                    warn "unknown colorspace: $_";
                }
            }
            default {
                warn "can't handle colorspace object of type: {.WHAT.^name}";
            }
        }
    }

    method !set-stroke-color { self!set-color($*gfx.StrokeColor, $*gfx.StrokeAlpha) }
    method !set-fill-color { self!set-color($*gfx.FillColor, $*gfx.FillAlpha) }

    method Save()      {
        $!ctx.save;
        @!gsave.push: %!current-font.clone;
    }
    method Restore()   {
        $!ctx.restore;
        if @!gsave {
            with @!gsave.pop {
                %!current-font = %$_;
            }
        }
    }
    method ClosePath() { $!ctx.close_path; }
    method Stroke()    {
        self!set-stroke-color;
        $!ctx.stroke;
    }
    method Fill(:$preserve=False) {
        self!set-fill-color;
        $!ctx.fill(:$preserve);
    }
    method FillStroke {
        self.Fill(:preserve);
        self.Stroke;
    }
    method CloseStroke {
        self.ClosePath;
        self.Stroke;
    }
    method CloseFillStroke {
        self.ClosePath;
        self.Fill(:preserve);
        self.Stroke;
    }
    method EOFill {
        temp $!ctx.fill_rule = Cairo::FILL_RULE_EVEN_ODD;
        self.Fill;
    }
    method EOFillStroke {
        temp $!ctx.fill_rule = Cairo::FILL_RULE_EVEN_ODD;
        self.FillStroke;
    }
    method CloseEOFillStroke {
        temp $!ctx.fill_rule = Cairo::FILL_RULE_EVEN_ODD;
        self.CloseFillStroke;
    }

    method EndPath() { $!ctx.new_path }

    method MoveTo(Numeric $x, Numeric $y) {
        $!ctx.move_to: |self!coords($x, $y);
    }

    method LineTo(Numeric $x, Numeric $y) {
        $!ctx.line_to: |self!coords($x, $y);
    }

    method SetLineCap(UInt $lc) {
        $!ctx.line_cap = do given $lc {
            when PDF-LineCaps::ButtCaps   { Cairo::LINE_CAP_BUTT }
            when PDF-LineCaps::RoundCaps  { Cairo::LINE_CAP_ROUND }
            when PDF-LineCaps::SquareCaps { Cairo::LINE_CAP_SQUARE }
        }
    }

    method SetLineJoin(UInt $lc) {
        $!ctx.line_join = do given $lc {
            when PDF-LineJoin::MiterJoin  { Cairo::LINE_JOIN_MITER }
            when PDF-LineJoin::RoundJoin  { Cairo::LINE_JOIN_ROUND }
            when PDF-LineJoin::BevelJoin  { Cairo::LINE_JOIN_BEVEL }
        }
    }

    method SetDashPattern(Array $pattern, Numeric $phase) {
        $!ctx.set_dash($pattern, $pattern.elems, $phase);
    }

    method SetLineWidth(Numeric $lw) {
        $!ctx.line_width = $lw;
    }

    method SetMiterLimit(Numeric $ml) {
        $!ctx.miter_limit = $ml;
    }

    method CurveTo(Numeric $x1, Numeric $y1, Numeric $x2, Numeric $y2, Numeric $x3, Numeric $y3) {
        my \c1 = self!coords($x1, $y1);
        my \c2 = self!coords($x2, $y2);
        my \c3 = self!coords($x3, $y3);
        $!ctx.curve_to(|c1, |c2, |c3);
    }

    method CurveToInitial(Numeric $x2, Numeric $y2, Numeric $x3, Numeric $y3) {
        my \c1 = self!coords($x2, $y2);
        my \c2 = self!coords($x3, $y3);
        my \c3 = c2;
        $!ctx.curve_to(|c1, |c2, |c3);
    }

    method CurveToFinal(Numeric $x1, Numeric $y1, Numeric $x3, Numeric $y3) {
        my \c1 = self!coords($x1, $y1);
        my \c3 = self!coords($x3, $y3);
        my \c2 = c3;
        $!ctx.curve_to(|c1, |c2, |c3);
    }

    method Rectangle(Numeric $x, Numeric $y, Numeric $w, Numeric $h) {
        $!ctx.rectangle( |self!coords($x, $y), $w, - $h);
    }

    method Clip { $!ctx.clip; }

    sub matrix-to-cairo(Num(Numeric) $scale-x, Num(Numeric) $skew-x,
                        Num(Numeric) $skew-y,  Num(Numeric) $scale-y,
                        Num(Numeric) $trans-x, Num(Numeric) $trans-y) {
       Cairo::Matrix.new.init(
            :xx($scale-x), :yy($scale-y),
            :yx(-$skew-x), :xy(-$skew-y),
            :x0($trans-x), :y0(-$trans-y),
            );
    }

    method !concat-matrix(*@matrix) {
        my $transform = matrix-to-cairo(|@matrix);
        $!ctx.transform( $transform );
    }
    method ConcatMatrix(*@matrix) {
        self!concat-matrix(|@matrix);
    }
    method !set-font(Hash $dict, Numeric $size)  {
        %!current-font = $!cache.protect: {
            $!cache.font{$dict} //= do {
                my PDF::Content::FontObj $font-obj = PDF::Font::Loader.load-font: :$dict;
                my $ft-face = $font-obj.face;

                my Cairo::Font $cairo-font .= create(
                    $ft-face.raw, :free-type,
                );
                %( :$font-obj, :$cairo-font, );
            }
        }
        %!current-font<size> = $size;
    }
    has %!scaled-font{Cairo::Font};
    method !scaled-font($s) {
        given  %!current-font<cairo-font> {
             $!cache.protect: {
                 $!cache.scaled-font{$_}{$s} //= do {
                     my Cairo::Matrix $scale .= new.scale($s, $s);
                     Cairo::ScaledFont.create($_, $scale, $!ctx.matrix);
                 }
            }
        }
    }

    method SetFont(|) {
        with $*gfx.Font {
            self!set-font: .[0], .[1];
        }
    }

    method SetGraphicsState(Str $_) {
        with $*gfx.resource-entry('ExtGState', $_) {
            with .<Font> { self.SetFont }
            with .<LJ>   { self.SetLineJoin($_) }
            with .<LC>   { self.SetLineCap($_) }
            with .<ML>   { self.SetMiterLimit($_) }
            with .<D>    { self.SetDashPattern(.[0], .[1]) }
            with .<LW>   { self.SetLineWidth($_) }
        }
    }
    enum BlendModes (
        :Normal(CAIRO_OPERATOR_OVER),
        :Compatible(CAIRO_OPERATOR_OVER),
        :Multiply(CAIRO_OPERATOR_MULTIPLY),
        :Screen(CAIRO_OPERATOR_SCREEN),
        :Overlay(CAIRO_OPERATOR_OVERLAY),
        :Darken(CAIRO_OPERATOR_DARKEN),
        :Lighten(CAIRO_OPERATOR_LIGHTEN),
        :ColorDodge(CAIRO_OPERATOR_COLOR_DODGE),
        :ColorBurn(CAIRO_OPERATOR_COLOR_BURN),
        :HardLight(CAIRO_OPERATOR_HARD_LIGHT),
        :SoftLight(CAIRO_OPERATOR_SOFT_LIGHT),
        :Difference(CAIRO_OPERATOR_DIFFERENCE),
        :Exclusion(CAIRO_OPERATOR_EXCLUSION),
        :Hue(CAIRO_OPERATOR_HSL_HUE),
        :Saturation(CAIRO_OPERATOR_HSL_SATURATION),
        :Color(CAIRO_OPERATOR_HSL_COLOR),
        :Luminosity(CAIRO_OPERATOR_HSL_LUMINOSITY),
    );
    constant %BlendModeCairo = BlendModes.enums.Hash;

    sub cairo-blend-mode(Str:D $_) {
        %BlendModeCairo{$_} // CAIRO_OPERATOR_OVER;
    }
    method !text-path($byte-str) {
        my PDF::Content::FontObj $font = %!current-font<font-obj>;
        my Numeric $size = %!current-font<size> / 1000;
        my @cids = $font.decode-cids($byte-str);
        my Num() $x = $!tx / $!hscale;
        my Num() $y = $!ty - $*gfx.TextRise;
        my $char-sp := $*gfx.CharSpacing;
        my $word-sp := $*gfx.WordSpacing;
        my $x0 = $x;
        my $y0 = $y;
        my PDF::Font::Loader::Glyph @pdf-glyphs = $font.get-glyphs(@cids);
        my Cairo::Glyphs $cairo-glyphs .= new: :elems(+@pdf-glyphs);
        my int $i = 0;
        my $ax = 0; # glyph advance
        my $sx = 0; # actual substituted font advance

        for @pdf-glyphs -> $pdf-glyph {
            given $cairo-glyphs[$i++] {
                .index = $pdf-glyph.gid;
                .x = $x + $ax;
                .y = $y;
            }
            $ax += $pdf-glyph.ax * $size;
            $sx += $pdf-glyph.sx || $pdf-glyph.ax;
            $x += $char-sp;
            $x += $word-sp
                if $word-sp && ($pdf-glyph.code-point == 32
                                || $pdf-glyph.name ~~ 'space');

            $y += $pdf-glyph.ay * $size;
        }

        unless $*gfx.TextRender == InvisableText {
            # do a simple adjustment to match requested to
            # actual glyph sizes

            with %!current-font<size> -> $fs {
                # do a simple adjustment to match requested to
                # actual glyph sizes
                my $ratio = $sx && $size ?? $ax / ($sx * $size) !! 1;
                $ratio = max(.75, min(1.5, $ratio));

                $!ctx.set_scaled_font: self!scaled-font($fs * $ratio);
                $!ctx.glyph_path($cairo-glyphs);
            }
        }

        $!tx += ($x + $ax - $x0) * $!hscale;
        $!ty += $y - $y0;
    }

    method !text-paint() {
        my \text-mode = $*gfx.TextRender;
        my \fill   = text-mode %% 2;
        my \stroke = 0 < (text-mode mod 4) < 3;
        my \clip   = text-mode >= 4;

        if fill {
            self!set-fill-color;
            $!ctx.fill: :preserve(stroke||clip);
        }

        if stroke {
            self!set-stroke-color;
            $!ctx.stroke: :preserve(clip);
        }

        if clip {
            .destroy with $!text-clip;
            $!text-clip = $!ctx.copy_path;
        }
    }

    method !text(&stuff) {
        $!ctx.save;
        self!concat-matrix: |$*gfx.TextMatrix;
        $!hscale = $*gfx.HorizScaling / 100.0;
        $!ctx.scale($!hscale, 1)
            unless $!hscale =~= 1.0;
        &stuff();
        self!text-paint();
        $!ctx.restore;
    }

    method ShowText($text-encoded) {
        self!text: {
            self!text-path: $text-encoded;
        }
    }
    method ShowSpaceText(List $text) {
        self!text: {
            my Numeric $font-size = $*gfx.Font[1];
            for $text.list {
                when Str {
                    self!text-path: $_;
                }
                when Numeric {
                    $!tx -= $_ * $font-size / 1000;
                }
            }
        }
    }

    method MoveShowText($text-encoded) is also<MoveSetShowText> {
        $!tx = 0.0;
        $!ty = 0.0;
        self.ShowText($text-encoded);
    }

    method EndText {
        with $!text-clip {
            $!ctx.append_path: $_;
            $!ctx.clip;
        }
    }

    method !render-form($canvas) {
        $!cache.protect: {
            $!cache.form{$canvas} //= do {
                my $nesting = $!nesting + 1;
                self.render: :$canvas, :transparent, :$!cache, :$nesting;
            }
        }
    }
    need PDF::Pattern::Tiling;
    method !render-tiling-pattern(PDF::Pattern::Tiling $pattern, $alpha) {
        my $img = $!cache.protect: {
            $!cache.pattern{$pattern}{$alpha} //= do {
                my $image = self!render-form($pattern);
                my $padded-img = Cairo::Image.create(
                    Cairo::FORMAT_ARGB32,
                    $pattern<XStep> // $image.width,
                    $pattern<YStep> // $image.height);
                my Cairo::Context $ctx .= new($padded-img);
                $ctx.set_source_surface($image);
                $ctx.paint_with_alpha($alpha);
                $padded-img;
            }
        }
        my Cairo::Pattern::Surface $patt .= create($img.surface);
        $patt.extend = Cairo::Extend::EXTEND_REPEAT;
        with $pattern.Matrix {
            my $ctm = matrix-to-cairo(|$*gfx.CTM);
            $patt.matrix = $ctm.multiply(matrix-to-cairo(|$_).invert);
        }
        $patt;
    }
    method !render-image(PDF::XObject::Image $xobject) {
        $!cache.protect: {
            $!cache.form{$xobject} //= do {
                my Cairo::Image $surface;
                do {
                    CATCH {
                        when X::NYI {
                            # draw stub placeholder rectangle
                            warn "stubbing image: {$xobject.raku}";
                            $surface .= create(Cairo::FORMAT_ARGB32, $xobject.width, $xobject.height);
                            my Cairo::Context $ctx .= new: $surface;
                            $ctx.new_path;
                            $ctx.rgba(.8,.8,.6, .5);
                            $ctx.rectangle(0, 0, $xobject.width, $xobject.height);
                            $ctx.fill(:preserve);
                            $ctx.rgba(.3,.3,.3, .5);
                            $ctx.line_width = 2;
                            $ctx.stroke;
                            $surface;
                        }
                    }

                    $surface = Cairo::Image.create($xobject.to-png.Buf);
                }
                $surface;
            }
        }
    }
    method !place-image(PDF::XObject $xobject) {
        $!ctx.save;

        my $surface = do given $xobject<Subtype> {
            when 'Form' {
                self!render-form($xobject);
            }
            when 'Image' {
                $!ctx.scale( 1/$xobject.width, 1/$xobject.height );
                self!render-image($xobject);
            }
        }

        with $surface {
            my List $bbox = $xobject.bbox;
            my Num() $alpha = $*gfx.FillAlpha;
            $!ctx.translate($bbox[0], -$bbox[3]);
            $!ctx.operator = cairo-blend-mode($*gfx.BlendMode);
            $!ctx.set_source_surface($_);
            $!ctx.paint_with_alpha($alpha);
        }

        $!ctx.restore;
    }
    method XObject($key) {
        with $*gfx.resource-entry('XObject', $key) {
            self!place-image($_);
        }
        else {
            warn "unable to locate XObject in resource dictionary: $key";
        }
    }

    has %!image-dict;
    method BeginImage(%!image-dict) { }
    method ImageData($encoded) {
        my %dict = PDF::XObject::Image.inline-to-xobject(%!image-dict);
        my PDF::XObject::Image() $image = { :%dict, :$encoded };
        self!place-image: $image;
    }
    method EndImage() { }

    ## -- Pass-Through Methods -- ##
    # - These methods update the graphics state for later reference.
    method SetStrokeRGB(*@) is also<
        SetFillRGB SetStrokeCMYK SetFillCMYK SetStrokeGray SetFillGray
        SetStrokeColorSpace SetFillColorSpace SetStrokeColor SetFillColor SetStrokeColorN SetFillColorN SetWordSpacing SetCharSpacing
    > { }

    # - These methods update the text state for later reference
    method SetTextLeading($) is also<SetTextRise SetHorizScaling SetTextRender> { }
    # - These methods update text state and also reset text-flow
    method BeginText(*@) is also<SetTextMatrix TextMove TextNextLine TextMoveSet> {
        $!tx = 0.0;
        $!ty = 0.0;
    }
    # - These methods have no affect on rendering
    method BeginMarkedContent(*@) is also<BeginMarkedContentDict EndMarkedContent MarkPointDict BeginExtended EndExtended> { }

    method callback{
        sub ($op, *@args) {
            my $method = OpCode($op).key;
            self."$method"(|@args);
            given $!ctx.status -> $status {
                die "bad Cairo status $status {Cairo::cairo_status_t($status).key} after $method\({@args}\) operation"
                    if $status;
            }
        }
    }

    our %nyi;
    method FALLBACK($method, *@args) {
        if $method ~~ /^<[A..Z]>/ {
            # assume unimplemented operator
            %nyi{$method} //= do {warn "can't do: $method\(@args[]\) yet";}
        }
        else {
            die X::Method::NotFound.new( :$method, :typename(self.^name) );
        }
    }

    multi method save-as-image(PDF::Content::Canvas $canvas, Str $filename where /:i '.png' $/, :$cache = Cache.new, |c) {
        my Cairo::Surface $surface = self.render: :$canvas, :$cache, |c;
        $surface.write_png: $filename;
    }

    multi method save-as-image(PDF::Content::Canvas $canvas, Str $filename where /:i '.svg' $/, :$cache = Cache.new, |c) {
        my Cairo::Surface::SVG $surface .= create($filename, $canvas.width, $canvas.height);
        my $feed = self.render: :$canvas, :$surface, :$cache, |c;
        $surface.finish;
    }

    multi method save-as(PDF::Class $pdf, Str() $outfile where /:i '.'('png'|'svg') $/, UInt :page($n), UInt :$batch=8, |c) {
        my \format = $0.lc;
        my UInt $pages = $pdf.page-count;
        my Cache $cache .= new;

        my @ =  (1 .. $pages).race(:$batch).map: -> UInt $page-num {
            next if $n.defined && $page-num != $n;
            my $img-filename = $outfile;
            if $outfile.index("%").defined {
                $img-filename = $outfile.sprintf($page-num);
            }
            else {
                die "invalid 'sprintf' output page format: $outfile"
                    if $pages > 1;
            }

            my $page = $pdf.page($page-num);
            $*ERR.print: "saving page $page-num -> {format.uc} $img-filename...\n"; 
            $.save-as-image($page, $img-filename, :$cache, |c);
        }
    }

    multi method save-as(PDF::Class $pdf, Str() $outfile where /:i '.pdf' $/, UInt :$batch=8, |c) {
        my $page1 = $pdf.page(1);
        my Cairo::Surface::PDF $surface .= create($outfile, $page1.width, $page1.height);
        my UInt $pages = $pdf.page-count;
        my Cache $cache .= new;

        my @ =  (1 .. $pages).race(:$batch).map: -> UInt $page-num {
            my $canvas = $pdf.page($page-num);
            self.render: :$canvas, :$surface, :$cache, |c;
            $surface.show_page;
        }
        $surface.finish;
     }

}
