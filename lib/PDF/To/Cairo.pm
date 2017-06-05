class PDF::To::Cairo {

    use PDF::Content::Ops :OpCode;
    has PDF::Content::Ops $!gfx;
    use Cairo;
    has $.content is required handles <width height>;
    has Numeric @.ctm is rw = [ 1, 0, 0, 1, 0, 0, ]; # cairo coordinates
    has Cairo::Surface $.surface = Cairo::Image.create(Cairo::FORMAT_ARGB32, self.width, self.height);
    has Cairo::Context $!ctx = Cairo::Context.new($!surface);

    method TWEAK() {
        $!content.render: sub ($op, *@args, :$obj) { self.callback($op, |@args, :$obj) };
    }

    method !init {
        $!ctx.translate(0, self.height);
    }

    method !coords(Numeric \x, Numeric \y) {
        (x, -y);
    }

    method Save() { $!ctx.save; }
    method Restore() { $!ctx.restore; }
    method ClosePath() { $!ctx.close_path; }
    method Stroke() { $!ctx.stroke; }

    method MoveTo(Numeric $x, Numeric $y) {
        $!ctx.move_to: |self!coords($x,$y);
    }

    method LineTo(Numeric $x, Numeric $y) {
        $!ctx.line_to: |self!coords($x,$y);
    }

    method CurveToInitial(Numeric $x1, Numeric $y1, Numeric $x2, Numeric $y2) {
        my \c1 = |self!coords($x1, $y1);
        my \c2 = |self!coords($x2, $y2);
        $!ctx.curve_to( |c1, |c2, |c2);
    }

    method callback($op, *@args, :$obj) {
        without $!gfx {$!gfx = $obj; self!init};
        my $method = OpCode($op).key;
        self."$method"(|@args);
    }

    method FALLBACK($name, *@args) { warn "can't do: $name\(@args[]\) yet"; }
}
