use v6;
use Test;
use PDF::Class;
use PDF::Render::Cairo;
use PDF::Content::Page :PageSizes;
use PDF::Content::Image;
use Cairo;

my $pdf = PDF::Class.new;
my $page = $pdf.add-page;
$page.MediaBox = PageSizes::Letter;
my $feed = PDF::Render::Cairo.new: :content($page);
$page.graphics: -> $gfx {
    my $font = $page.core-font( :family<Helvetica> );
    my $y = $page.MediaBox[3];

    my $form = $page.xobject-form: :BBox[0,0,150,150];
    $form.graphics: {
        .font = $form.core-font( :family<Times-Roman>, :weight<bold>, :style<italic> );
        .FillColor = :DeviceRGB[ .8, .9, .9];
        .Rectangle(5,5,140,140);
        .Fill;
    }
    $form.text: {
        .text-position = [10, 120];
        .say: 'Hello, world!';
    }
    $form.finish;

    $gfx.do($form, 10, 100 );
    $gfx.MoveTo(10, 95);
    $gfx.LineTo(160,95);
    $gfx.Stroke; 

    my $image = PDF::Content::Image.open: "t/images/crosshair-100x100.png";
    $gfx.do($image, 10, 300);

}
lives-ok {$feed.surface.write_png: "t/xobject.png"}, 'write_png';
$pdf.save-as: "t/xobject.pdf";

done-testing;
