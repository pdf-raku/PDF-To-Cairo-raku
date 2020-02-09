#!/usr/bin/env perl6
use v6;
use PDF::Class;
use PDF::To::Cairo;

sub MAIN(
    Str $directory = '.',         #| directory to be scanned for PDFS
    Str :$previews = '.previews', #| where to place previews
    Str :$password = '',          #| password for the input PDF, if encrypted
    Bool :$recursive = False;
    ) {

    my $preview-dir = $directory.IO.add($previews);
    mkdir $preview-dir;

    for $directory.IO.dir( :test(/:i '.pdf' $/) ) -> $input {
warn $input;
        my $pdf = PDF::Class.open( $input, :$password);
        my $png-out = $preview-dir.IO.add: $input.IO.basename.subst(/:i '.pdf' $/, '-%03d.png');

        my UInt $pages = $pdf.page-count;

        for 1 .. $pages -> UInt $page-num {
            my $content = $pdf.page($page-num);
            $content.pre-graphics: {
                # insert a border
                .StrokeColor = :DeviceRGB[.5, .6, .6 ];
                .Rectangle: |$content.MediaBox;
                .Stroke;
            };
            my $filename = $png-out.sprintf($page-num);
            $*ERR.print: "saving $input page $page-num -> $filename...\n"; 
            $content.save-as-image($filename);
        }
    }
}

=begin pod

=head1 NAME

pdf-previews.pl - Scan a directory for PDF files. Create PNG previews

=head1 SYNOPSIS

 pdf-previews.pl [directory] --previews=directory

 Options:
   --pasword=str       # provide default password for encrypted PDF files

=head1 DESCRIPTION

This program bursts a multiple page into single page PNG files.

By default, the output pdf will be named infile001.png infile002.png ...

The `outspec`, if present, will be used as a 'sprintf' template
for generation of the individual per-page output PNG files.

** This is neither fast, or complete ** It exists to exercise other
components in the Perl 6 ecosystem, including PDF::Content and Cairo.

=head1 SEE ALSO

PDF::Class
PDF::Content
PDF::Render::Cairo

=head1 AUTHOR

See L<PDF>

=end pod
