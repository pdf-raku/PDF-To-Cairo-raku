# PDF-To-Cairo-p6

Some experimental PDF rendering to Cairo via the Perl 6 PDF Tool-chain.

To burst my.pdf to PNG images my-001.png my-002.png ...

bin/pdf2image.p6 my.pdf 

Current renders:
- simple text (no word or character spacing etc)
- most drawing and graphics operators
- form XObjects
- some (mostly PNG like) image XObjects (depends on state
  of PDF::Class PDF::Image.to-png() method)
- Gray, RGB, CMYK, DeviceN and Separation color-spaces
- Tiling patterns (not shading)
