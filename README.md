# PDF-To-Cairo-raku

Some experimental PDF rendering to Cairo via the Raku PDF Tool-chain.

To burst my.pdf to PNG images my-001.png my-002.png ...

bin/pdf2image.raku my.pdf

Current renders:
- basic text, including fonts, word and character spacing
- most drawing and graphics operators
- form XObjects
- some (mostly PNG like) image XObjects (depends on state
  of PDF::Class PDF::Image.to-png() method)
- Gray, RGB, CMYK, DeviceN and Separation color-spaces
- Tiling patterns (not shading)
