#!/usr/bin/env perl6
use v6.c;
use PDF::Lite;
use PDF::Content::Cairo;
use PDF::Content::Ops :OpCode;
use GTK::Simple;
use GTK::Simple::DrawingArea;
use Cairo;

class PDF::Tracer {

    has PDF::Lite $.pdf is required;

    my class Renderer is PDF::Content::Cairo {
        has Numeric $.delay = 1.0;
        my uint $counter = 0;
        method callback{
            sub ($op, *@args) {
                my $method = OpCode($op).key;
                note "$op\({@args.join(', ')}\)\t% $method";
                self."$method"(|@args);
            }
        }
    }

    method render($da, $ctx, $content) {
        Renderer.render( :$content, :$ctx, :surface(Nil));
        return 0;
    }

    method trace-page($file, UInt $page-num) {
        constant Border = 5;
        gtk_simple_use_cairo;

        my $app = GTK::Simple::App.new: :title("Tracing $file page $page-num");
        my $da = GTK::Simple::DrawingArea.new;
        my $page = $!pdf.page($page-num);
        $da.size-request($page.width + 2 * Border, $page.height + 2 * Border);
        my $ctx = $da.add-draw-handler( sub ($da, $ctx) { self.render($da, $ctx, $page); } );
        $app.set-content( $da );
        $app.border-width = Border;
        $app.run;
    }


}

sub MAIN(Str $infile,            #| input PDF
         Int :$page = 1,
	 Str :$password = '',    #| password for the input PDF, if encrypted
    ) {

    my $input = $infile eq q{-}
        ?? $*IN
	!! $infile;

    my $pdf = PDF::Lite.open( $input, :$password);
    my $tracer = PDF::Tracer.new: :$pdf;
    $tracer.trace-page($infile, $page);
}


