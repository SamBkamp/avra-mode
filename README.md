# avra-mode

`avra-mode` is a major mode for editing [AVRA][avra] AVR assembly
programs. It includes syntax highlighting, automatic indentation, and
imenu integration. Requires Emacs 24.3 or higher.

this project is forked from [nasm-mode][nasm-mode-gh]

The instruction and keyword lists are from the [AVR ISA][ISA].

## Known Issues

* Due to limitations of Emacs' syntax tables, like many other major
  modes, double and single quoted strings don't properly handle
  backslashes, which, unlike backquoted strings, aren't escapes in
  NASM syntax.

[ISA]: https://ww1.microchip.com/downloads/en/DeviceDoc/Atmel-7810-Automotive-Microcontrollers-ATmega328P_Datasheet.pdf?trk=public_post_comment-text#G1447661
[avra]: https://github.com/Ro5bert/avra
[nasm-mode-gh]: https://github.com/skeeto/nasm-mode