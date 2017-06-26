use v6;
use PDF::Content::Image::PNG :PNG-CS;

class PDF::Content::Cairo::PNG
    is PDF::Content::Image::PNG {

    use PDF::DAO::Stream;
    my subset ImageStream of PDF::DAO::Stream where .<Subtype> ~~ 'Image';
    my subset PNGPredictor of Int where 10 .. 15;

    method from-dict(ImageStream $dict) {
        my $bit-depth = $dict<BitsPerComponent> || 8;
        my UInt $width = $dict<Width>;
        my UInt $height = $dict<Height>;
        my PDF::Content::Image::PNG::Header $hdr .= new: :$width, :$height, :$bit-depth;
        my buf8 $stream;
        my buf8 $palette;
        my buf8 $trans;
        my $decode-parms = $dict<DecodeParms>;
        if $decode-parms
            && $dict<Filter> ~~ 'FlateDecode'
            && $decode-parms<Predictor> ~~ PNGPredictor {
                # stream is good to go
                $stream = buf8.new: $dict.encoded.encode: "latin-1";
        }
        else {
            # could reencode stream. use case?
            warn "ignoring decode-params: {$decode-parms.perl}";
            return Nil;
        }

        my subset IndexedRGBColorSpace of Array where {
            .elems >= 4
                && .[0] ~~ 'Indexed'
                && .[1] ~~ 'DeviceRGB'
        }
        given $dict<ColorSpace> {
            when IndexedRGBColorSpace {
                $hdr.color-type = PNG-CS::RGB-Palette;
                my Str $data = .isa(PDF::DAO::Stream) ?? .encoded !! $_
                    with .[3];
                $palette = buf8.new: .encode("latin-1") with $data;
                with $dict<SMask> {
                    $trans = .stream
                        with self.to-dict: $_;
                }
            }
            when 'DeviceRGB'|'DeviceGray' { 
                $hdr.color-type = $dict<ColorSpace> ~~ 'DeviceRGB'
                    ?? PNG-CS::RGB !! PNG-CS::Gray;
                my \colors =  $hdr.color-type == RGB
                    ?? 3 !! 1;
                if $dict<SMask> && $bit-depth == 8|16  {
                    # SMask contains alpha channel - merge it
                    with self.from-dict: $dict<SMask> {
                        my buf8 $alpha-channel = .stream;
                        my buf8 $color-channel = $stream;
                        my uint $c-len = +$color-channel;
                        my uint $na = $bit-depth div 8;
                        my uint $nc = colors * $na;
                        my uint $a = 0;
                        my uint $c = 0;
                        my uint $i = 0;
                        $stream = buf8.allocate: ($c-len * 4) div 3;
                        while $c < $c-len {
                            $stream[$i++] = $color-channel[$c++]
                                for 1 .. $nc;
                            $stream[$i++] = $alpha-channel[$a++]
                                for 1 .. $na;
                        }
                        $hdr.color-type = $dict<ColorSpace> ~~ 'DeviceRGB'
                            ?? PNG-CS::RGB-Alpha !! PNG-CS::Gray-Alpha;
                    }
                }
            }
            default {
                warn "ignoring color-space: {.perl}";
                return Nil;
            }
        }

        my $obj = self.new: :$hdr, :$stream;
        $obj.palette = $_ with $palette;
        $obj.trans = $_ with $trans;
        $obj;
    }
}
