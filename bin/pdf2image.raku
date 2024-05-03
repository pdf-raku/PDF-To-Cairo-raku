#!/usr/bin/env raku
use v6;
use PDF::Class;
use PDF::To::Cairo;

#| reading from stdin
multi sub output-filename('-', $) {"pdf-page-%03d.png"}
#| user supplied format spec
multi sub output-filename(Str $filename where /'%'/, $) {$filename}
#| generated sprintf format from input/output filename template
multi sub output-filename(Str $infile, PDF::Class:D $pdf) is default {
    my $digits = $pdf.Root.Pages.Count.fmt("%d").chars;
    my $fmt = '-%0' ~ $digits ~ 'd.png';
    my Str $ext = $infile.IO.extension;
    $ext eq ''
        ?? $infile ~ $fmt
        !! $infile.subst(/ '.' $ext$/, $fmt);
}

subset ImageFile of Str where Str:U|/:i '.' [png|svg|pdf]/;

sub MAIN(Str $infile,             #| input PDF
         ImageFile $outfile? is copy,      #| output PNG, SVG or PDF file
         Bool :$trace = False,    #| trace execution
         UInt :$page,             #| page to render
         UInt :$batch = 8,        #| thread batch size (pages)
	 Str  :$password = '',    #| password for the input PDF, if encrypted
    ) {

    my $input = $infile eq q{-}
        ?? $*IN
	!! $infile;

    my PDF::Class $pdf .= open( $input, :$password);
    $outfile //= output-filename($infile, $pdf);
    PDF::To::Cairo.save-as($pdf, $outfile, :$page, :$trace, :$batch);
}

=begin pod

=head1 NAME

pdf2image.raku - Convert a PDF to PNG, or SVG images, using Perl 6!

=head1 SYNOPSIS

 pdf2png.p6 [options] infile.pdf [outspec.png]

 Options:
   --password=str       # provide a password for an encrypted PDF
   --page=n             # render just this page
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
