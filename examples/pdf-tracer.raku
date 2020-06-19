#!/usr/bin/env perl6
use v6.c;
use PDF::Class;
use PDF::Page;
use PDF::To::Cairo;
use PDF::Content::Ops :OpCode;
use GTK::Simple;
use GTK::Simple::DrawingArea;
use Cairo;

class PDF::Tracer {
    has PDF::Class $.pdf is required;

    my class Renderer is PDF::To::Cairo {
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

        my GTK::Simple::App $app .= new: :title("Tracing $file page $page-num");
        my GTK::Simple::DrawingArea $da .= new;
        my PDF::Page $page = $!pdf.page($page-num);
        $da.size-request($page.width + 2 * Border, $page.height + 2 * Border);
        my $ctx = $da.add-draw-handler: -> $da, $ctx { self.render($da, $ctx, $page); };
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

    my PDF::Class $pdf .= open: $input, :$password;
    my $tracer = PDF::Tracer.new: :$pdf;
    $tracer.trace-page($infile, $page);
}


