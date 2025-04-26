#!/usr/bin/env raku
use v6;
use PDF::Class;
use PDF::To::Cairo;

subset ImageFile of Str where Str:U|/:i '.' [png|svg|pdf]/;

sub MAIN(Str $infile,             #| input PDF
         ImageFile $outfile? is copy,      #| output PNG, SVG or PDF file
         Bool :$trace = False,    #| trace execution
         UInt :$batch = 8,        #| thread batch size (pages)
         UInt :$burst = 10,       #| render n pages at a time (PDF only)
	 Str  :$password = '',    #| password for the input PDF, if encrypted
    ) {

    my $input = $infile eq q{-}
        ?? $*IN
	!! $infile;

    $outfile //= $infile eq q{-}
        ?? "stdin-%03d.png" !! $infile.subst(/:i '.pdf' $/, '.png'); 

    my PDF::Class $pdf .= open( $input, :$password);

    PDF::To::Cairo.save-as($pdf, $outfile, :$trace, :$batch);
}

=begin pod

=head1 NAME

pdf2image.raku - Convert a PDF to PNG, or SVG images, using Perl 6!

=head1 SYNOPSIS

 pdf2png.p6 [options] infile.pdf [outspec.png]

 Options:
   --password=str       # provide a password for an encrypted PDF
   --batch=n            # thread batch size (pages)
   --burst=n            # render n pages at a time (PDF only)
   --trace --debug      # debugging/tracing

=head1 DESCRIPTION

This program bursts a multiple page into single page PNG files.

By default, the output pdf will be named infile-001.png infile-
                002.png ...

The `outspec`, if present, will be used as a 'sprintf' template
for generation of the individual output PNG files.

** This is neither fast, or complete ** It exists to exercise other
components in the Raku ecosystem, including PDF::Content and Cairo.

=head1 SEE ALSO

PDF::Class
PDF::Content
PDF::Font::Loader
PDF::To::Cairo

=head1 AUTHOR

See L<PDF>

=end pod
