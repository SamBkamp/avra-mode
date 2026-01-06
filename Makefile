.POSIX:
.SUFFIXES: .el .elc
EMACS = emacs

compile: avra-mode.elc

clean:
	rm -f avra-mode.elc

.el.elc:
	$(EMACS) -Q -batch -f batch-byte-compile $<
