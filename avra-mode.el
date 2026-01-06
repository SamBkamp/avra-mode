;;; avra-mode.el --- AVR assembly major mode -*- lexical-binding: t; -*-

;; This is free and unencumbered software released into the public domain.

;; Author: Sam Bonnekamp <sam@bonnekamp.net>
;; URL: https://github.com/SamBkamp/avra-mode
;; Version: 1.1.1
;; Package-Requires: ((emacs "24.3"))

;;; Commentary:

;; A major mode for editing AVRA AVR assembly programs.  It includes
;; syntax highlighting, automatic indentation, and imenu integration.

;; Labels without colons are not recognized as labels by this mode,
;; since, without a parser equal to that of NASM itself, it's
;; otherwise ambiguous between macros and labels.  This covers both
;; indentation and imenu support.

;; The keyword lists are up to date as of NASM 2.12.01.
;; http://www.nasm.us/doc/nasmdocb.html

;; TODO:
;; [ ] Line continuation awareness
;; [x] Don't run comment command if type ';' inside a string
;; [ ] Nice multi-; comments, like in asm-mode
;; [x] Be able to hit tab after typing mnemonic and insert a TAB
;; [ ] Autocompletion
;; [ ] Help menu with basic summaries of instructions
;; [ ] Highlight errors, e.g. size mismatches "mov al, dword [rbx]"
;; [ ] Work nicely with outline-minor-mode
;; [ ] Highlighting of multiline macro definition arguments

;;; Code:

(require 'imenu)

(defgroup avra-mode ()
  "Options for `avra-mode'."
  :group 'languages)

(defgroup avra-mode-faces ()
  "Faces used by `avra-mode'."
  :group 'avra-mode)

(defcustom avra-basic-offset (default-value 'tab-width)
  "Indentation level for `avra-mode'."
  :type 'integer
  :group 'avra-mode)

(defcustom avra-after-mnemonic-whitespace :tab
  "In `avra-mode', determines the whitespace to use after mnemonics.
This can be :tab, :space, or nil (do nothing)."
  :type '(choice (const :tab) (const :space) (const nil))
  :group 'avra-mode)

(defface avra-registers
  '((t :inherit (font-lock-variable-name-face)))
  "Face for registers."
  :group 'avra-mode-faces)

(defface avra-prefix
  '((t :inherit (font-lock-builtin-face)))
  "Face for prefix."
  :group 'avra-mode-faces)

(defface avra-types
  '((t :inherit (font-lock-type-face)))
  "Face for types."
  :group 'avra-mode-faces)

(defface avra-instructions
  '((t :inherit (font-lock-builtin-face)))
  "Face for instructions."
  :group 'avra-mode-faces)

(defface avra-directives
  '((t :inherit (font-lock-keyword-face)))
  "Face for directives."
  :group 'avra-mode-faces)

(defface avra-preprocessor
  '((t :inherit (font-lock-preprocessor-face)))
  "Face for preprocessor directives."
  :group 'avra-mode-faces)

(defface avra-labels
  '((t :inherit (font-lock-function-name-face)))
  "Face for nonlocal labels."
  :group 'avra-mode-faces)

(defface avra-local-labels
  '((t :inherit (font-lock-function-name-face)))
  "Face for local labels."
  :group 'avra-mode-faces)

(defface avra-section-name
  '((t :inherit (font-lock-type-face)))
  "Face for section name face."
  :group 'avra-mode-faces)

(defface avra-constant
  '((t :inherit (font-lock-constant-face)))
  "Face for constant."
  :group 'avra-mode-faces)

(eval-and-compile
  (defconst avra-registers
    '("r0" "r1" "r2" "r3" "r4" "r5" "r6" "r7" "r8" "r9" "r10"
      "r11" "r12" "r13" "r14" "r15" "r16" "r17" "r18" "r19" "r20"
      "r21" "r22" "r23" "r24" "r25" "r26" "r27" "r28" "r29" "r30" "r31")
    "AVRA registers (reg.c) for `avra-mode'."))

(eval-and-compile
  (defconst avra-directives
    '("absolute" "bits" "common" "cpu" "debug" "default" "extern"
      "float" "global" "list" "section" "segment" "warning" "sectalign"
      "export" "group" "import" "library" "map" "module" "org" "osabi"
      "safeseh" "uppercase")
    "AVRA directives (directiv.c) for `avra-mode'."))

(eval-and-compile
  (defconst avra-instructions
    '("add" "adc" "adiw" "sub" "subi" "sbc" "sbci" "sbiw" "and"
      "andi" "or" "ori" "eor" "com" "neg" "sbr" "cbr" "inc" "dec"
      "tst" "clr" "ser" "mul" "muls" "mulsu" "fmul" "fmuls" "fmulsu"
      "rjmp" "ijmp" "jmp" "rcall" "icall" "call" "ret" "reti" "cpse"
      "cp" "cpc" "cpi" "sbrc" "sbrs" "sbic" "sbis" "brbs" "brbc"
      "breq" "brne" "brcs" "brcc" "brsh" "brlo" "brmi" "brpl" "brge"
      "brlt" "brhs" "brhc" "brts" "brtc" "brvs" "brvc" "brie" "brid"
      "sbi" "cbi" "lsl" "lsr" "rol" "ror" "asr" "swap" "bset" "bclr"
      "bst" "bld" "sec" "clc" "sen" "cln" "sez" "clz" "sei" "cli"
      "ses" "cls" "sev" "clv" "set" "clt" "seh" "clh" "mov" "movw"
      "ldi" "ld" "lds" "lpm" "in" "out" "push" "pop" "nop" "sleep"
      "wdr" "break" "spm" "st" "sts")
    "AVRA instructions (tokhash.c) for `avra-mode'."))

(eval-and-compile
  (defconst avra-types
    '("1to16" "1to2" "1to4" "1to8" "__float128h__" "__float128l__"
      "__float16__" "__float32__" "__float64__" "__float80e__"
      "__float80m__" "__float8__" "__infinity__" "__nan__" "__qnan__"
      "__snan__" "__utf16__" "__utf16be__" "__utf16le__" "__utf32__"
      "__utf32be__" "__utf32le__" "abs" "byte" "dword" "evex" "far"
      "long" "near" "nosplit" "oword" "qword" "rel" "seg" "short"
      "strict" "to" "tword" "vex2" "vex3" "word" "wrt" "yword"
      "zword")
    "AVRA types (tokens.dat) for `avra-mode'."))

(eval-and-compile
  (defconst avra-prefix
    '("a16" "a32" "a64" "asp" "lock" "o16" "o32" "o64" "osp" "rep" "repe"
      "repne" "repnz" "repz" "times" "wait" "xacquire" "xrelease" "bnd")
    "AVRA prefixes (nasmlib.c) for `avra-mode'."))

(eval-and-compile
  (defconst avra-pp-directives
    '("%elif" "%elifn" "%elifctx" "%elifnctx" "%elifdef" "%elifndef"
      "%elifempty" "%elifnempty" "%elifenv" "%elifnenv" "%elifid"
      "%elifnid" "%elifidn" "%elifnidn" "%elifidni" "%elifnidni"
      "%elifmacro" "%elifnmacro" "%elifnum" "%elifnnum" "%elifstr"
      "%elifnstr" "%eliftoken" "%elifntoken" "%if" "%ifn" "%ifctx"
      "%ifnctx" "%ifdef" "%ifndef" "%ifempty" "%ifnempty" "%ifenv"
      "%ifnenv" "%ifid" "%ifnid" "%ifidn" "%ifnidn" "%ifidni" "%ifnidni"
      "%ifmacro" "%ifnmacro" "%ifnum" "%ifnnum" "%ifstr" "%ifnstr"
      "%iftoken" "%ifntoken" "%arg" "%assign" "%clear" "%define"
      "%defstr" "%deftok" "%depend" "%else" "%endif" "%endm" "%endmacro"
      "%endrep" "%error" "%exitmacro" "%exitrep" "%fatal" "%iassign"
      "%idefine" "%idefstr" "%ideftok" "%imacro" "%include" "%irmacro"
      "%ixdefine" "%line" "%local" "%macro" "%pathsearch" "%pop" "%push"
      "%rep" "%repl" "%rmacro" "%rotate" "%stacksize" "%strcat"
      "%strlen" "%substr" "%undef" "%unimacro" "%unmacro" "%use"
      "%warning" "%xdefine" "istruc" "at" "iend" "align" "alignb"
      "struc" "endstruc" "__LINE__" "__FILE__" "%comment" "%endcomment"
      "__NASM_MAJOR__" " __NASM_MINOR__" "__NASM_SUBMINOR__"
      "___NASM_PATCHLEVEL__" "__NASM_VERSION_ID__" "__NASM_VER__"
      "__BITS__" "__OUTPUT_FORMAT__" "__DATE__" "__TIME__" "__DATE_NUM__"
      "__TIME_NUM__" "__UTC_DATE__" "__UTC_TIME__" "__UTC_DATE_NUM__"
      "__UTC_TIME_NUM__" "__POSIX_TIME__" " __PASS__" "SECTALIGN")
    "AVRA preprocessor directives (pptok.c) for `avra-mode'."))

(defconst avra-nonlocal-label-rexexp
  "\\(\\_<[a-zA-Z_?][a-zA-Z0-9_$#@~?]*\\_>\\)\\s-*:"
  "Regexp for `avra-mode' for matching nonlocal labels.")

(defconst avra-local-label-regexp
  "\\(\\_<\\.[a-zA-Z_?][a-zA-Z0-9_$#@~?]*\\_>\\)\\(?:\\s-*:\\)?"
  "Regexp for `avra-mode' for matching local labels.")

(defconst avra-label-regexp
  (concat avra-nonlocal-label-rexexp "\\|" avra-local-label-regexp)
  "Regexp for `avra-mode' for matching labels.")

(defconst avra-constant-regexp
  "\\_<$?[-+]?[0-9][-+_0-9A-Fa-fHhXxDdTtQqOoBbYyeE.]*\\_>"
  "Regexp for `avra-mode' for matching numeric constants.")

(defconst avra-section-name-regexp
  "^\\s-*section[ \t]+\\(\\_<\\.[a-zA-Z0-9_$#@~.?]+\\_>\\)"
  "Regexp for `avra-mode' for matching section names.")

(defmacro avra--opt (keywords)
  "Prepare KEYWORDS for `looking-at'."
  `(eval-when-compile
     (regexp-opt ,keywords 'symbols)))

(defconst avra-imenu-generic-expression
  `((nil ,(concat "^\\s-*" avra-nonlocal-label-rexexp) 1)
    (nil ,(concat (avra--opt '("%define" "%macro"))
                  "\\s-+\\([a-zA-Z0-9_$#@~.?]+\\)") 2))
  "Expressions for `imenu-generic-expression'.")

(defconst avra-full-instruction-regexp
  (eval-when-compile
    (let ((pfx (avra--opt avra-prefix))
          (ins (avra--opt avra-instructions)))
      (concat "^\\(" pfx "\\s-+\\)?" ins "$")))
  "Regexp for `avra-mode' matching a valid full AVRA instruction field.
This includes prefixes or modifiers (eg \"mov\", \"rep mov\", etc match)")

(defconst avra-font-lock-keywords
  `((,avra-section-name-regexp (1 'avra-section-name))
    (,(avra--opt avra-registers) . 'avra-registers)
    (,(avra--opt avra-prefix) . 'avra-prefix)
    (,(avra--opt avra-types) . 'avra-types)
    (,(avra--opt avra-instructions) . 'avra-instructions)
    (,(avra--opt avra-pp-directives) . 'avra-preprocessor)
    (,(concat "^\\s-*" avra-nonlocal-label-rexexp) (1 'avra-labels))
    (,(concat "^\\s-*" avra-local-label-regexp) (1 'avra-local-labels))
    (,avra-constant-regexp . 'avra-constant)
    (,(avra--opt avra-directives) . 'avra-directives))
  "Keywords for `avra-mode'.")

(defconst avra-mode-syntax-table
  (with-syntax-table (copy-syntax-table)
    (modify-syntax-entry ?_  "_")
    (modify-syntax-entry ?#  "_")
    (modify-syntax-entry ?@  "_")
    (modify-syntax-entry ?\? "_")
    (modify-syntax-entry ?~  "_")
    (modify-syntax-entry ?\. "w")
    (modify-syntax-entry ?\; "<")
    (modify-syntax-entry ?\n ">")
    (modify-syntax-entry ?\" "\"")
    (modify-syntax-entry ?\' "\"")
    (modify-syntax-entry ?\` "\"")
    (syntax-table))
  "Syntax table for `avra-mode'.")

(defvar avra-mode-map
  (let ((map (make-sparse-keymap)))
    (prog1 map
      (define-key map (kbd ":") #'avra-colon)
      (define-key map (kbd ";") #'avra-comment)
      (define-key map [remap join-line] #'avra-join-line)))
  "Key bindings for `avra-mode'.")

(defun avra-colon ()
  "Insert a colon and convert the current line into a label."
  (interactive)
  (call-interactively #'self-insert-command)
  (avra-indent-line))

(defun avra-indent-line ()
  "Indent current line (or insert a tab) as AVRA assembly code.
This will be called by `indent-for-tab-command' when TAB is
pressed.  We indent the entire line as appropriate whenever POINT
is not immediately after a mnemonic; otherwise, we insert a tab."
  (interactive)
  (let ((before      ; text before point and after indentation
         (save-excursion
           (let ((point (point))
                 (bti (progn (back-to-indentation) (point))))
             (buffer-substring-no-properties bti point)))))
    (if (string-match avra-full-instruction-regexp before)
        ;; We are immediately after a mnemonic
        (cl-case avra-after-mnemonic-whitespace
          (:tab   (insert "\t"))
          (:space (insert-char ?\s avra-basic-offset)))
      ;; We're literally anywhere else, indent the whole line
      (let ((orig (- (point-max) (point))))
        (back-to-indentation)
        (if (or (looking-at (avra--opt avra-directives))
                (looking-at (avra--opt avra-pp-directives))
                (looking-at "\\[")
                (looking-at ";;+")
                (looking-at avra-label-regexp))
            (indent-line-to 0)
          (indent-line-to avra-basic-offset))
        (when (> (- (point-max) orig) (point))
          (goto-char (- (point-max) orig)))))))

(defun avra--current-line ()
  "Return the current line as a string."
  (save-excursion
    (let ((start (progn (beginning-of-line) (point)))
          (end (progn (end-of-line) (point))))
      (buffer-substring-no-properties start end))))

(defun avra--empty-line-p ()
  "Return non-nil if current line has non-whitespace."
  (not (string-match-p "\\S-" (avra--current-line))))

(defun avra--line-has-comment-p ()
  "Return non-nil if current line contains a comment."
  (save-excursion
    (end-of-line)
    (nth 4 (syntax-ppss))))

(defun avra--line-has-non-comment-p ()
  "Return non-nil of the current line has code."
  (let* ((line (avra--current-line))
         (match (string-match-p "\\S-" line)))
    (when match
      (not (eql ?\; (aref line match))))))

(defun avra--inside-indentation-p ()
  "Return non-nil if point is within the indentation."
  (save-excursion
    (let ((point (point))
          (start (progn (beginning-of-line) (point)))
          (end (progn (back-to-indentation) (point))))
      (and (<= start point) (<= point end)))))

(defun avra-comment-indent ()
  "Compute desired indentation for comment on the current line."
  comment-column)

(defun avra-insert-comment ()
  "Insert a comment if the current line doesn’t contain one."
  (let ((comment-insert-comment-function nil))
    (comment-indent)))

(defun avra-comment (&optional arg)
  "Begin or edit a comment with context-sensitive placement.

The right-hand comment gutter is far away from the code, so this
command uses the mark ring to help move back and forth between
code and the comment gutter.

* If no comment gutter exists yet, mark the current position and
  jump to it.
* If already within the gutter, pop the top mark and return to
  the code.
* If on a line with no code, just insert a comment character.
* If within the indentation, just insert a comment character.
  This is intended prevent interference when the intention is to
  comment out the line.

With a prefix ARG, kill the comment on the current line with
`comment-kill'."
  (interactive "p")
  (if (not (eql arg 1))
      (comment-kill nil)
    (cond
     ;; Empty line, or inside a string? Insert.
     ((or (avra--empty-line-p) (nth 3 (syntax-ppss)))
      (insert ";"))
     ;; Inside the indentation? Comment out the line.
     ((avra--inside-indentation-p)
      (insert ";"))
     ;; Currently in a right-side comment? Return.
     ((and (avra--line-has-comment-p)
           (avra--line-has-non-comment-p)
           (nth 4 (syntax-ppss)))
      (goto-char (mark))
      (pop-mark))
     ;; Line has code? Mark and jump to right-side comment.
     ((avra--line-has-non-comment-p)
      (push-mark)
      (comment-indent))
     ;; Otherwise insert.
     ((insert ";")))))

(defun avra-join-line (&optional arg)
  "Join this line to previous, but use a tab when joining with a label.
With prefix ARG, join the current line to the following line.  See `join-line'
for more information."
  (interactive "*P")
  (join-line arg)
  (if (looking-back avra-label-regexp (line-beginning-position))
      (let ((column (current-column)))
        (cond ((< column avra-basic-offset)
               (delete-char 1)
               (insert-char ?\t))
              ((and (= column avra-basic-offset) (eql ?: (char-before)))
               (delete-char 1))))
    (avra-indent-line)))

;;;###autoload
(define-derived-mode avra-mode prog-mode "AVRA"
  "Major mode for editing AVRA assembly programs."
  :group 'avra-mode
  (make-local-variable 'indent-line-function)
  (make-local-variable 'comment-start)
  (make-local-variable 'comment-insert-comment-function)
  (make-local-variable 'comment-indent-function)
  (setf font-lock-defaults '(avra-font-lock-keywords nil :case-fold)
        indent-line-function #'avra-indent-line
        comment-start ";"
        comment-indent-function #'avra-comment-indent
        comment-insert-comment-function #'avra-insert-comment
        imenu-generic-expression avra-imenu-generic-expression))

(provide 'avra-mode)

;;; avra-mode.el ends here
