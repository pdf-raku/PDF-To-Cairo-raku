# PDF-To-Cairo-raku

Example
-------

To burst `my.pdf` to PNG images `my-001.png` `my-002.png` ...

### Via the shell

```shell
bin/pdf2image.raku my.pdf
```

### Via Raku

```raku
use PDF::Class;
use PDF::To::Cairo;

my PDF::Class $pdf .= open: "my.pdf";
my $outfile-templ = "my-%03d.png";

PDF::To::Cairo.save-as($pdf, $outfile-templ);
```

Description
----------
This module is an experimental work-in-progress PDF rendering via Cairo and the Raku PDF Tool-chain.
It is able to render from [PDF::Class](https://pdf-raku.github.io/PDF-Class-raku/) or [PDF::API6](https://pdf-raku.github.io/PDF-API6/) objects. Supported output formats are `PNG`, `PDF` (round trip) and `SVG`.

This module can currently render text (most fonts), simple colors, tiling patterns and basic graphics.

At this stage its main purpose is to exercise Raku modules related
to PDF, fonts and rendering, including:

- [PDF](https://pdf-raku.github.io/PDF-raku/) (threading)
- [PDF::Content](https://pdf-raku.github.io/PDF-Content-raku/)  (graphics, images)
- [PDF::Font::Loader](https://pdf-raku.github.io/PDF-Font-Loader-raku/) (font loading, decoding, rendering, threading)
- [PDF::Class](https://pdf-raku.github.io/PDF-Class-raku/) (objects)]
- [Font::FreeType](https://pdf-raku.github.io/Font-FreeType-raku/) (fonts and glyphs)
- [Cairo](https://github.com/timo/cairo-p6) (rendering)


Scripts
------

#### `pdf2image.raku --page=n --batch=m --trace --password=*** <in>.pdf [out-fmt]`

Where

- `<in>.pdf` is a PDF file

- `[out-fmt]` is an option output file format specification (default <in>-%03d.png).

##### `pdf2image.raku` Options

- `--page=n` render just the `n`th page in the PDF file
- `--batch=m` render to threads of batch size `m`
- `--trace`

#### `pdf-previews.raku` <directory> --previews=<directory>`

Render all PDF files in a given input directory (default `.`) and render PNG previews
to a given output directory; by default to a `.previews` subdirectory in the input directory.

Status
------

Implemented:
- basic text, including fonts, word and character spacing
- most drawing and graphics operators
- form XObjects
- some (mostly PNG like) image XObjects (depends on state
  of PDF::Class PDF::Image.to-png() method)
- Gray, RGB, CMYK, DeviceN and Separation color-spaces
- Tiling patterns (not shading)

Nyi:
- advanced clipping and graphics settings
- many image types
- shading patterns
- some font types (in particular Type3 synthetic fonts)


