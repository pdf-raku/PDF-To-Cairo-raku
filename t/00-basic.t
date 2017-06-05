use v6;
use Test;
use PDF::Lite;
use PDF::To::Cairo;

my $pdf = PDF::Lite.new;
my $page = $pdf.add-page;
my $feed = PDF::To::Cairo.new: :content($page);
my $gfx = $page.gfx;

$gfx.Save;
$gfx.MoveTo(175, 720);
$gfx.LineTo(175, 700);
$gfx.CurveToInitial( 300, 800,  400, 720 );
$gfx.ClosePath;
$gfx.Stroke;
$gfx.Restore;
$pdf.save-as: "t/00-basic.pdf";
lives-ok {$feed.surface.write_png: "t/00-basic.png"}, 'write to png';
done-testing;
