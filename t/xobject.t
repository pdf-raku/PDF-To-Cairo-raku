use v6;
use Test;
use PDF::Lite;
use PDF::To::Cairo;
use PDF::Content::Util::TransformMatrix;
use PDF::Content::Page :PageSizes;
use PDF::Content::Image;
use Cairo;

my $pdf = PDF::Lite.new;
my $page = $pdf.add-page;
$page.MediaBox = PageSizes::Letter;
my $feed = PDF::To::Cairo.new: :content($page);
$page.graphics: -> $gfx {
    my $font = $page.core-font( :family<Helvetica> );
    my $y = $page.MediaBox[3];

    my $form = $pdf.xobject-form: :BBox[0,0,150,150];
    $form.graphics: {
        .font = $form.core-font( :family<Times-Roma>, :weight<bold>, :style<italic> );
        .FillColor = :DeviceRGB[ .8, .9, .9];
        .Rectangle(5,5,140,140);
        .Fill;
    }
    $form.text: {
        .text-position = [10, 120];
        .say: 'Hello, world!';
    }
    $form.finish;

    $page.graphics: {
        .do($form, 10, 100 );
        .MoveTo(10, 95);
        .LineTo(160,95);
        .Stroke; 
    }

    my $image = PDF::Content::Image.open: "t/images/crosshair-100x100.png";
    $page.graphics: {
        .do($image, 10, 300);
    }

}
$feed.surface.write_png: "t/xobject.png";
$pdf.save-as: "t/xobject.pdf";

done-testing;
