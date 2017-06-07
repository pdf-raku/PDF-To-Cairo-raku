class PDF::To::Cairo {

    use Cairo;
    use Color;
    use PDF::Content::Ops :OpCode;
    has PDF::Content::Ops $!gfx;
    has $.content is required handles <width height>;
    has Cairo::Surface $.surface = Cairo::Image.create(Cairo::FORMAT_ARGB32, self.width, self.height);
    has Cairo::Context $.ctx = Cairo::Context.new($!surface);

    method TWEAK() {
        $!content.render: sub ($op, *@args, :$obj) { self.callback($op, |@args, :$obj) };
    }

    method !init {
        $!ctx.translate(0, self.height);
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
                my @rgb = (1..3).map: {$colors[0] - 1.0};
                $!ctx.rgb( |@rgb );
            }
            default {
                warn "can't handle colorspace: $_";
            }
        }
    }
    method !set-stroke-color { self!set-color($!gfx.StrokeColor) }
    method !set-fill-color { self!set-color($!gfx.StrokeColor) }

    method Save()      { $!ctx.save; }
    method Restore()   { $!ctx.restore; }
    method ClosePath() { $!ctx.close_path; }
    method Stroke()    {
        self!set-stroke-color;
        $!ctx.stroke;
    }
    method SetStrokeRGB(*@) {}
    method SetFillRGB(*@) {}

    method MoveTo(Numeric $x, Numeric $y) {
        $!ctx.move_to: |self!coords($x,$y);
    }

    method LineTo(Numeric $x, Numeric $y) {
        $!ctx.line_to: |self!coords($x,$y);
    }

    method CurveToInitial(Numeric $x1, Numeric $y1, Numeric $x2, Numeric $y2) {
        my \c1 = |self!coords($x1, $y1);
        my \c2 = |self!coords($x2, $y2);
        $!ctx.curve_to(|c1, |c2, |c2);
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

    method callback($op, *@args, :$obj) {
        without $!gfx {$!gfx = $obj; self!init};
        my $method = OpCode($op).key;
        self."$method"(|@args);
    }

    method FALLBACK($name, *@args) { warn "can't do: $name\(@args[]\) yet"; }
}
