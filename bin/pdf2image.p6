#!/usr/bin/env perl6
use v6;
use PDF::Zen;
use PDF::Content;
use PDF::Content::Graphics;
use PDF::Content::Cairo;

#| reading from stdin
multi sub output-filename('-') {"pdf-page-%03d.png"}
#| user supplied format spec
multi sub output-filename(Str $filename where /'%'/) {$filename}
#| generated sprintf format from input/output filename template
multi sub output-filename(Str $infile) is default {
      my Str $ext = $infile.IO.extension;
      $ext eq ''
      ?? $infile ~ '-%03d.png'
      !! $infile.subst(/ '.' $ext$/, '-%03d.png');
}

subset ImageFile of Str where /:i '.' [png|svg|pdf]/;

sub MAIN(Str $infile,            #| input PDF
         ImageFile $outfile = output-filename($infile),
	 Str :$password = '',    #| password for the input PDF, if encrypted
    ) {

    my $input = $infile eq q{-}
        ?? $*IN
	!! $infile;

    my $pdf = PDF::Zen.open( $input, :$password);
    PDF::Content::Cairo.save-as($pdf, $outfile);
}

=begin pod

=head1 NAME

pdf2png.p6 - Convert a PDF to PNG images, using .... (wait for it) ... Perl 6!

=head1 SYNOPSIS

 pdf2png.p6 [options] infile.pdf [outspec.png]

 Options:
   --pasword=str       # provide a password for  an encrypted PDF

=head1 DESCRIPTION

This program bursts a multiple page into single page PNG files.

By default, the output pdf will be named infile001.png infile002.png ...

The `outspec`, if present, will be used as a 'sprintf' template
for generation of the individual output PNG files.

** This is neither fast, or complete ** It exists to exercise other
components in the Perl 6 ecosystem, including PDF::Content and Cairo.

=head1 SEE ALSO

PDF::Zen
PDF::Content
PDF::Content::Cairo

=head1 AUTHOR

See L<PDF>

=end pod
