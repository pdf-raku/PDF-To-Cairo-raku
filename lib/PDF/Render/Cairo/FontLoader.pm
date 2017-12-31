class PDF::Render::Cario::FontLoader {
    use PDF::Font::Loader;
    use PDF::DAO::Dict;
    use PDF::Font;
    use PDF::Encoding;

    method !base-enc($_, :$dict!) {
        when 'Identity-H'       {'identity-h' }
        when 'WinAnsiEncoding'  { 'win' }
        when 'MacRomanEncoding' { 'mac' }
        default {
            Mu
        }
    }

    method load-font(PDF::Font :$dict!, |c) {
        use PDF::Font::Loader::Enc::CMap;
        my $enc;
        my %opt;

        with $dict<ToUnicode> -> $cmap {
            $enc = PDF::Font::Loader::Enc::CMap.new: :$cmap;
        }
        else {
            $enc = do with $dict<Encoding> {
                when PDF::Encoding {
                    %opt<differences> = $_ with .Differences;
                    self!base-enc(.<BaseEncoding>, :$dict);
                }
                default { self!base-enc($_, :$dict); }
            }
        }

        %opt<enc> = $_ with $enc;
        %opt<first-char>  = $_ with $dict<FirstChar>;
        %opt<last-char>   = $_ with $dict<LastChar>;
        %opt<widths>      = $_ with $dict<Widths>; # todo: handle in PDF::Font::Loader

        constant SymbolicFlag = 1 +< 5;
        constant ItalicFlag = 1 +< 6;

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
                %opt<font-stream> = .decoded;
            }

            # See [PDF 32000 Table 114 - Entries in an encoding dictionary]
            %opt<enc> //= %opt<font-stream>.defined || $dict.Flags +& SymbolicFlag
                ?? 'std'
                !! 'identity';

        }
        else {
            # no font descriptor. assume core font
            %opt<enc> //= do given $dict.BaseFont {
                when /:i ^[ZapfDingbats|WebDings]/ {'zapf'}
                when /:i ^[Symbol]/ {'sym'}
                default {'identity'}
            }
            %opt<name> = $dict.BaseFont // 'courier';
        }
        PDF::Font::Loader.load-font( |%opt );
    }

}
