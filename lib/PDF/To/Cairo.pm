class PDF::To::Cairo {

    use Cairo;
    use Color;
    use PDF::Content::Ops :OpCode, :LineCaps, :LineJoin;
    has PDF::Content::Ops $!gfx;
    use PDF::Content::Font;
    has $.content is required handles <width height>;
    has Cairo::Surface $.surface = Cairo::Image.create(Cairo::FORMAT_ARGB32, self.width, self.height);
    has Cairo::Context $.ctx = Cairo::Context.new($!surface);
    has $!current-font;
    has Hash @!save;

    method TWEAK() {
        $!content.render: sub ($op, *@args, :$obj) { self.callback($op, |@args, :$obj) };
    }

    method !init {
        $!ctx.translate(0, self.height);
        $!ctx.line_width = $!gfx.LineWidth;
        $!ctx.rgb(1.0, 1.0, 1.0);
        $!ctx.paint;
    }

    method !coords(Numeric \x, Numeric \y) {
        (x, -y);
    }

    method !set-color($_) {
        my ($cs, $colors) = .kv;
        given $cs {
            when 'DeviceRGB' {
                $!ctx.rgb( |$colors );
            }
            when 'DeviceGray' {
                my @rgb = $colors[0] xx 3;
                $!ctx.rgb( |@rgb );
            }
            when 'DeviceCMYK' {
                my Color $color .= new: :cmyk($colors);
                my @rgb = $color.rgb.map: * / 255;
                $!ctx.rgb( |@rgb );
            }
            default {
                warn "can't handle colorspace: $_";
            }
        }
    }
    method !set-stroke-color { self!set-color($!gfx.StrokeColor) }
    method !set-fill-color { self!set-color($!gfx.FillColor) }

    method Save()      {
        $!ctx.save;
        @!save.push: %(
            :font($!current-font)
        );
    }
    method Restore()   {
        $!ctx.restore;
        if @!save {
            with @!save.pop {
                $!current-font = .<font>;
            }
        }
    }
    method ClosePath() { $!ctx.close_path; }
    method Stroke()    {
        self!set-stroke-color;
        $!ctx.stroke;
    }
    method Fill(:$preserve=False)    {
        self!set-fill-color;
        $!ctx.fill(:$preserve);
    }
    method FillStroke {
        self.Fill(:preserve);
        self.Stroke;
    }
    method SetStrokeRGB(*@) {}
    method SetFillRGB(*@) {}
    method SetStrokeCMYK(*@) {}
    method SetFillCMYK(*@) {}
    method SetStrokeGray(*@) {}
    method SetFillGray(*@) {}
    method EndPath() { $!ctx.new_path }

    method MoveTo(Numeric $x, Numeric $y) {
        $!ctx.move_to: |self!coords($x,$y);
    }

    method LineTo(Numeric $x, Numeric $y) {
        $!ctx.line_to: |self!coords($x,$y);
    }

    method SetLineCap(UInt $lc) {
        $!ctx.line_cap = do given $lc {
            when ButtCaps   { Cairo::LineCap::LINE_CAP_BUTT }
            when RoundCaps  { Cairo::LineCap::LINE_CAP_ROUND }
            when SquareCaps { Cairo::LineCap::LINE_CAP_SQUARE }
        }
    }

    method SetLineJoin(UInt $lc) {
        $!ctx.line_join = do given $lc {
            when MiterJoin  { Cairo::LineJoin::LINE_JOIN_MITER }
            when RoundJoin  { Cairo::LineJoin::LINE_JOIN_ROUND }
            when BevelJoin  { Cairo::LineJoin::LINE_JOIN_BEVEL }
        }
    }

    method SetDashPattern(Array $pattern, Numeric $phase) {
        $!ctx.set_dash($pattern, $pattern.elems, $phase);
    }

    method SetLineWidth(Numeric $lw) {
        $!ctx.line_width = $lw;
    }

    method CurveTo(Numeric $x1, Numeric $y1, Numeric $x2, Numeric $y2, Numeric $x3, Numeric $y3) {
        my \c1 = |self!coords($x1, $y1);
        my \c2 = |self!coords($x2, $y2);
        my \c3 = |self!coords($x3, $y3);
        $!ctx.curve_to(|c1, |c2, |c3);
    }

    method CurveToInitial(Numeric $x1, Numeric $y1, Numeric $x2, Numeric $y2) {
        my \c1 = |self!coords($x1, $y1);
        my \c2 = |self!coords($x2, $y2);
        $!ctx.curve_to(|c1, |c2, |c2);
    }

    method Rectangle(Numeric $x, Numeric $y, Numeric $w, Numeric $h) {
        $!ctx.rectangle( |self!coords($x, $y), $w, - $h);
    }

    method ConcatMatrix(Num(Numeric) $scale-x, Num(Numeric) $skew-x,
                        Num(Numeric) $skew-y, Num(Numeric) $scale-y,
                        Num(Numeric) $trans-x, Num(Numeric) $trans-y) {

        my $transform = Cairo::cairo_matrix_t.new(
            :xx($scale-x), :yy($scale-y),
            :yx(-$skew-x), :xy(-$skew-y),
            :x0($trans-x), :y0(-$trans-y),
            );

        $!ctx.transform( $transform );
    }

    method BeginText() { }
    method SetFont($font-key, $font-size) {
        with $!gfx.resource-entry('Font', $font-key) {
            $!current-font = PDF::Content::Font.from-dict($_);
        }
        else {
            warn "unable to locate Font in resource dictionary: $font-key";
            $!current-font = Nil;
        }
    }
    method EndText() { }

    method BeginMarkedContent(Str) { }
    method BeginMarkedContentDict(Str, Hash) { }
    method EndMarkedContent() { }

    method callback($op, *@args, :$obj) {
        without $!gfx {$!gfx = $obj; self!init};
        my $method = OpCode($op).key;
        self."$method"(|@args);
    }

    our %nyi;
    method FALLBACK($name, *@args) { %nyi{$name} //= do {warn "can't do: $name\(@args[]\) yet";} }
}
