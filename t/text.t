use v6;
use Test;
use PDF::Lite;
use PDF::To::Cairo;
use PDF::Content::Util::TransformMatrix;
use Cairo;

my $pdf = PDF::Lite.new;
my $page = $pdf.add-page;
$page.MediaBox = [0, 0, 150, 200];
my $feed = PDF::To::Cairo.new: :content($page);
$page.graphics: -> $gfx {
    my $font = $page.core-font( :family<Helvetica> );
    $page.text: {
        .set-font($font, 10);
        isa-ok $feed.current-font, 'Font::Metrics::helvetica', 'current-font';
        .text-position = [50, 50];
        .print('Hello World!');
    }
}
$feed.surface.write_png: "t/text.png";
$pdf.save-as: "t/text.pdf";

done-testing;
