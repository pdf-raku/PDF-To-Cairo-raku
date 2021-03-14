use v6;
use Test;
use PDF::Class;
use PDF::Page;
use PDF::To::Cairo;
use PDF::Content::Page :PageSizes;
use PDF::Content::XObject;
use PDF::Content::Color :rgb;
use Cairo;

my PDF::Class $pdf .= new;
my $page = $pdf.add-page;
$page.MediaBox = PageSizes::Letter;
my PDF::To::Cairo $feed .= new: :content($page);
$page.graphics: -> $gfx {
    my $y = $page.MediaBox[3];

    my PDF::Content::XObject $form = $page.xobject-form: :BBox[0,0,150,150];
    $form.graphics: {
        .FillColor = rgb( .8, .9, .9);
        .Rectangle(5,5,140,140);
        .Fill;
    }
    $form.text: {
        .font = $form.core-font( :family<Times-Roman>, :weight<bold>, :style<italic> );
        .text-position = [10, 120];
        .say: 'Hello, world!';
    }

    $gfx.do($form, 10, 100 );
    $gfx.MoveTo(10, 95);
    $gfx.LineTo(160,95);
    $gfx.Stroke; 

    my PDF::Content::XObject $image .= open: "t/images/crosshair-100x100.png";
    $gfx.do($image, 10, 300);

    # form with non-zero origin
    $form = $page.xobject-form: :BBox[-10,-10,80,80];
    $form.graphics: {
        .FillColor = rgb( .8, .9, .9);
        .Rectangle(-10,-10,80,80);
        .Fill;
    }
    $form.text: {
        .font = $form.core-font( :family<Times-Roman>, :weight<bold>, :style<italic> );
        .text-position = [0, 0];
        .say: 'this is 0,0';
    }
    $gfx.do($form, 10, 450);
}
lives-ok {$feed.surface.write_png: "t/xobject.png"}, 'write_png';
$pdf.save-as: "t/xobject.pdf";

done-testing;
