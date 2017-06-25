use v6;
use Test;
use PDF::Lite;
use PDF::Content::Cairo;
use PDF::Content::Matrix :scale, :translate, :skew, :rotate;

my $pdf = PDF::Lite.new;
my $page = $pdf.add-page;
my $feed = PDF::Content::Cairo.new: :content($page);
my $gfx = $page.gfx;

$gfx.Save;
$gfx.MoveTo(175, 720);
$gfx.LineTo(175, 700);
$gfx.CurveToInitial( 300, 800,  400, 720 );
$gfx.ClosePath;
$gfx.Stroke;

my $x = 10;
my $y = 600;

$gfx.LineWidth = 3;

for [ :DeviceGray[.2], :DeviceGray[.5] ],
    [ :DeviceGray[.75], :DeviceGray[.5] ],
    [ :DeviceRGB[.9, .1, .1,], :DeviceRGB[.1, .1, .9] ],
    [ :DeviceCMYK[.9, .1, .1, .1], :DeviceCMYK[.1, .1, .9, .5] ] {
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

$pdf.save-as: "t/00-basic.pdf";
lives-ok {$feed.surface.write_png: "t/00-basic.png"}, 'write to png';
done-testing;
