use v6;
use Test;
use PDF::Class;
use PDF::Render::Cairo;
use PDF::Content::Matrix :translate, :rotate;
use Cairo:ver(v0.2.1..*);

my $pdf = PDF::Class.new;
my $page = $pdf.add-page;
$page.MediaBox = [0, 0, 150, 200];
my $feed = PDF::Render::Cairo.new: :content($page);
my $gfx = $page.gfx;

$gfx.Save;
is-deeply $feed.ctx.matrix, Cairo::Matrix.new.init( :y0(200) ), 'matrix initial';
$gfx.ConcatMatrix(2, 0, 0, 3, 0, 0);
is-deeply $feed.ctx.matrix, Cairo::Matrix.new.init( :xx(2), :yy(3), :y0(200) ), 'scale';
$gfx.Restore;
is-deeply $feed.ctx.matrix, Cairo::Matrix.new.init( :xx(1), :yy(1), :y0(200) ), 'restore';

my $translate = Cairo::Matrix.new.init( :translate, 20, -30);

$gfx.Save;
$gfx.ConcatMatrix: translate(20,30);
is-deeply $feed.ctx.matrix, Cairo::Matrix.new.init( :x0(20), :y0(170) ), 'translate';
$gfx.Restore;

$gfx.Save;
$gfx.ConcatMatrix: rotate(pi/4);
my $matrix = $feed.ctx.matrix;
given $matrix {
      is-approx .xx, 0.5.sqrt, 'rotate xx';
      is-approx .yx, -0.5.sqrt, 'rotate yx';
      is-approx .xy, 0.5.sqrt, 'rotate xy';
      is-approx .yy, 0.5.sqrt, 'rotate yy';
      is-approx .x0, 0, 'rotate x0';
      is-approx .y0, 200, 'rotate y0';
}
$gfx.Restore;

done-testing;
