use v6;
use Test;
use PDF::Class;
use PDF::To::Cairo;
use PDF::Content;
use PDF::Content::Canvas;
use PDF::Content::Matrix :scale, :translate, :skew, :rotate;
use PDF::Content::Color :rgb, :gray, :cmyk;

my PDF::Class $pdf .= new;
my PDF::Content::Canvas $canvas = $pdf.add-page;
my PDF::To::Cairo $feed .= new: :$canvas;
my PDF::Content $gfx = $canvas.gfx;

$gfx.Save;
$gfx.MoveTo(175, 720);
$gfx.LineTo(175, 700);
$gfx.CurveToInitial( 300, 800,  400, 720 );
$gfx.CurveToFinal( 150, 800,  350, 720 );
$gfx.ClosePath;
$gfx.Stroke;

my $x = 10;
my $y = 600;

$gfx.LineWidth = 3;

for [ gray(.2), gray(.5) ],
    [ gray(.75), gray(.5) ],
    [ rgb(.9, .1, .1,), rgb(.1, .1, .9) ],
    [ cmyk(.9, .1, .1, .1), cmyk(.1, .1, .9, .5) ],
    [ cmyk(.0, .0, .0, .3), cmyk(.0, .0, .0, 1.0) ] {
    $gfx.FillColor = .[0];
    $gfx.StrokeColor = .[1];
    $gfx.Rectangle($x, $y, 40, 40);
    $gfx.FillStroke;
    $x += 60;
}

$gfx.Restore;

$gfx.Save;

$gfx.MoveTo(50,50);
$gfx.LineTo(50,100);
$gfx.Stroke;

$gfx.SetStrokeRGB(1.0,.2,.2);
$gfx.ConcatMatrix: scale(1.2);
$gfx.MoveTo(50,50);
$gfx.LineTo(50,100);
$gfx.Stroke;

$gfx.SetStrokeRGB(.2, 1.0, .2);
$gfx.ConcatMatrix: translate(8,8);
$gfx.MoveTo(50,50);
$gfx.LineTo(50,100);
$gfx.Stroke;

$gfx.Save;
$gfx.SetStrokeRGB(.2, .2, 1.0);
$gfx.ConcatMatrix: skew(.15);
$gfx.MoveTo(50,50);
$gfx.LineTo(50,100);
$gfx.Stroke;
$gfx.ConcatMatrix: skew(.15);
$gfx.MoveTo(50,50);
$gfx.LineTo(50,100);
$gfx.Stroke;
$gfx.Restore;

$gfx.Save;
$gfx.SetStrokeRGB(.7, .2, .7);
$gfx.ConcatMatrix: rotate(.1);
$gfx.MoveTo(50,50);
$gfx.LineTo(50,100);
$gfx.Stroke;
$gfx.ConcatMatrix: rotate(.1);
$gfx.MoveTo(50,50);
$gfx.LineTo(50,100);
$gfx.Stroke;
$gfx.Restore;

$gfx.Restore;

$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
$pdf.save-as: "t/draw.pdf", :!info;
lives-ok {$feed.surface.write_png: "t/draw.png"}, 'write to png';

done-testing;
