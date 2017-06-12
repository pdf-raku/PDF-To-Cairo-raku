#!/usr/bin/env perl6
use v6;
use PDF::Lite;
use PDF::Content;
use PDF::Content::Graphics;
use PDF::To::Cairo;

#| reading from stdin
multi sub output-filename('-') {"pdf-page%03d.png"}
#| user supplied format spec
multi sub output-filename(Str $filename where /'%'/) {$filename}
#| generated sprintf format from input/output filename template
multi sub output-filename(Str $infile) is default {
      my Str $ext = $infile.IO.extension;
      $ext eq ''
      ?? $infile ~ '%03d.png'
      !! $infile.subst(/ '.' $ext$/, '%03d.png');
}

sub MAIN(Str $infile,            #| input PDF
         Str $outfile = output-filename($infile),
	 Str :$password = '',    #| password for the input PDF, if encrypted
	 Str :$save-as is copy,  #| output template filename
    ) {

    $save-as = output-filename( $save-as // $infile );

    my $input = $infile eq q{-}
        ?? $*IN
	!! $infile;

    my $doc = PDF::Lite.open( $input, :$password);

    my UInt $pages = $doc.page-count;

    for 1 .. $pages -> UInt $page-num {

	my $png_filename = $save-as.sprintf($page-num);
	die "invalid 'sprintf' output page format: $save-as"
	    if $png_filename eq $save-as && $pages > 1;

	my $page = $doc.page($page-num);
        $*ERR.print: "saving page $page-num -> $png_filename...\n"; 
        convert($page, $png_filename);
    }

    sub convert(PDF::Content::Graphics $content, Str $png-filename) {
        my $feed = PDF::To::Cairo.new: :$content;
        $content.gfx;
        $feed.surface.write_png: $png-filename;
    }

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

PDF::Lite
PDF::Content
PDF::To::Cairo

=head1 AUTHOR

See L<PDF>

=end pod
