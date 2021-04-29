use v6;
use Test;
use PDF::Class;
use PDF::Page;
use PDF::To::Cairo;
use PDF::Content::Page :PageSizes;
use PDF::Content::Color :rgb;
use Cairo;

my PDF::Class $pdf .= new;
my PDF::Page $page = $pdf.add-page;
$page.MediaBox = PageSizes::Letter;
my PDF::To::Cairo $feed .= new: :content($page), :!trace;
$page.graphics: -> $gfx {
    my $font = $page.core-font( :family<Helvetica> );
    my $y = $page.MediaBox[3];

    $page.text: {
        .font = $font, 10;
        .text-position = [50, $y -= 20];
        .print('Hello World!');
        .text-position = [10, $y -= 20];
        my $text = $['The', -500, 'long', -500, 'and', -200, 'short.'];
        .ShowSpaceText($text);
        .font = $font, 15;
        .text-position = [10, $y -= 20];
        .ShowSpaceText($text);

        .text-position = [10, $y -= 20];

        .SetTextLeading(10);
        .ShowText("this ");
        .ShowText("line");
        .TextNextLine;
        .ShowText("next ");
        .ShowText("line. ");
        .TextMoveSet(5,-10);
        .ShowText("descended+indented text");
        .MoveShowText("move-show-text");
 
        .text-position = [10, $y -= 55];

        .ShowText("text ");

        .TextRise = 3;
        .ShowText("rise ");

        .TextRise = 0;
        .ShowText("and ");

        .TextRise = -3;
        .ShowText("fall.");
    }

    $page.graphics: {
        $page.text: {
            .text-position = [10, $y -= 40];
            .set-font($font, 32);
            .FillColor = rgb(.7, .2, .2);
            .StrokeColor = rgb(.2, .7, .7);
            for 0 .. 7 -> $m {
                .TextRender = $m;
                .ShowText("M$m ");
            }
        }
        .FillColor = rgb( .5, .9, .5);
        .Rectangle(10, $y+1, 420, 12);
        .Fill;
    }

    $page.text: {
        .text-position = [10, $y -= 30];

        for 100, 75, 150 -> $hs {
            .HorizScaling = $hs;
            .ShowText("HorizScale $hs ");
        }
     }
}
$feed.surface.write_png: "t/text.png";
$pdf.id = $*PROGRAM-NAME.fmt('%-16.16s');
lives-ok { $pdf.save-as: "t/text.pdf", :!info };

done-testing;
