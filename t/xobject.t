use v6;
use Test;
use PDF::Class;
use PDF::Page;
use PDF::Render::Cairo;
use PDF::Content::Page :PageSizes;
use PDF::Content::XObject;
use PDF::Content::Color :rgb;
use Cairo;

my PDF::Class $pdf .= new;
my $page = $pdf.add-page;
$page.MediaBox = PageSizes::Letter;
my PDF::Render::Cairo $feed .= new: :content($page);
$page.graphics: -> $gfx {
    my $font = $page.core-font( :family<Helvetica> );
    my $y = $page.MediaBox[3];

    my PDF::Content::XObject $form = $page.xobject-form: :BBox[0,0,150,150];
    $form.graphics: {
        .font = $form.core-font( :family<Times-Roman>, :weight<bold>, :style<italic> );
        .FillColor = rgb( .8, .9, .9);
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

    my PDF::Content::XObject $image .= open: "t/images/crosshair-100x100.png";
    $gfx.do($image, 10, 300);

}
lives-ok {$feed.surface.write_png: "t/xobject.png"}, 'write_png';
$pdf.save-as: "t/xobject.pdf";

done-testing;
