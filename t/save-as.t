use Test;
plan 3;
use PDF::Class;
use PDF::To::Cairo;

mkdir 'tmp';

for <svg pdf png> -> $ext {
    my PDF::Class:D $pdf .= open: "t/text.pdf";
    my $outfile = 'tmp/text.' ~ $ext;
    lives-ok {PDF::To::Cairo.save-as($pdf, $outfile)}, "save as {$ext.uc}";
}
done-testing;
