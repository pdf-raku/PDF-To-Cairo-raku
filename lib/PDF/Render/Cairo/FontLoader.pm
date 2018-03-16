class PDF::Render::Cairo::FontLoader {
    use PDF::Font::Loader;
    use PDF::Font;
    use PDF::Font::Type0;
    use PDF::Encoding;

    method !base-enc($_, :$dict!) {
        when 'Identity-H'       {'identity-h' }
        when 'WinAnsiEncoding'  { 'win' }
        when 'MacRomanEncoding' { 'mac' }
        default { Mu }
    }

    method load-font(PDF::Font :$dict! is copy, |c) {
        use PDF::Font::Loader::Enc::CMap;
        my %opt;

        %opt<enc> = do with $dict<Encoding> {
            when PDF::Encoding {
                %opt<differences> = $_ with .Differences;
                self!base-enc(.<BaseEncoding>, :$dict);
            }
            default { self!base-enc($_, :$dict); }
        }

        %opt<enc> //= PDF::Font::Loader::Enc::CMap.new: :cmap($_)
            with $dict<ToUnicode>;

        %opt<first-char>  = $_ with $dict<FirstChar>;
        %opt<last-char>   = $_ with $dict<LastChar>;
        %opt<widths>      = $_ with $dict<Widths>; # todo: handle in PDF::Font::Loader

        constant SymbolicFlag = 1 +< 5;
        constant ItalicFlag = 1 +< 6;

        $dict = $dict.DescendantFonts[0]
            if $dict ~~ PDF::Font::Type0;

        with $dict<FontDescriptor> {
            # embedded font
            %opt<width> = .lc with .FontStretch;
            %opt<weight> = $_ with .FontWeight;
            %opt<slant> = 'italic'
                if .ItalicAngle // (.Flags +& ItalicFlag);
            %opt<name> = .FontFamily // do {
                with $dict.BaseFont {
                    # remove any subset prefix
                    .subst(/^<[A..Z]>**6'+'/,'');
                }
                else {
                    'courier';
                }
            }
            with .FontFile // .FontFile2 // .FontFile3 {
                my $font-stream = .decoded;
                $font-stream = $font-stream.encode("latin-1")
                    unless $font-stream ~~ Blob;
                %opt<font-stream> = $font-stream;
            }

            # See [PDF 32000 Table 114 - Entries in an encoding dictionary]
            %opt<enc> //= %opt<font-stream>.defined || $dict.Flags +& SymbolicFlag
                ?? 'std'
                !! 'identity';

        }
        else {
            # no font descriptor. assume core font
            my $face = $dict.BaseFont // 'courier';
            %opt<weight> = 'bold' if $face ~~ s/:i ['-'|',']? bold //;
            %opt<slant> = $0.lc if $face ~~ s/:i ['-'|',']? (italic|oblique) //;
            %opt<name> = $face;
            %opt<enc> //= do given $face {
                when /:i ^[ZapfDingbats|WebDings]/ {'zapf'}
                when /:i ^[Symbol]/ {'sym'}
                default {'std'}
            }
        }
        PDF::Font::Loader.load-font( |%opt );
    }

}
