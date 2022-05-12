use v6;
use Test;
use PDF::Class;
use PDF::Content;
use PDF::Content::Canvas;
use PDF::To::Cairo;
use PDF::Content::Page :PageSizes;
use PDF::Content::XObject;
use PDF::Content::Color :rgb;
use Cairo;

my PDF::Class $pdf .= new;
my PDF::Content::Canvas $canvas = $pdf.add-page;
$canvas.MediaBox = PageSizes::Letter;
my PDF::To::Cairo $feed .= new: :$canvas;
$canvas.graphics: -> $gfx {
    my $y = $canvas.MediaBox[3];

    my PDF::Content::XObject $form = $canvas.xobject-form: :BBox[0,0,150,150];
    $form.graphics: {
        .FillColor = rgb( .8, .9, .9);
        .Rectangle(5,5,140,140);
        .Fill;
    }
    $form.text: {
        .font = $pdf.core-font( :family<Times-Roman>, :weight<bold>, :style<italic> );
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
    $form = $canvas.xobject-form: :BBox[-10,-10,80,80];
    $form.graphics: {
        .FillColor = rgb( .8, .9, .9);
        .Rectangle(-10,-10,80,80);
        .Fill;
    }
    $form.text: {
        .font = $pdf.core-font( :family<Times-Roman>, :weight<bold>, :style<italic> );
        .text-position = [0, 0];
        .say: 'this is 0,0';
    }
    $gfx.do($form, 10, 450);
}
lives-ok {$feed.surface.write_png: "t/xobject.png"}, 'write_png';
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
$pdf.save-as: "t/xobject.pdf", :!info;

done-testing;
