# `:extension` 

**Filename extensions used to collect lists of files searched in [`:paths`](paths.md)**

Ceedling uses path lists and wildcard matching against filename extensions to collect file lists.

Each file type below accepts either a single extension or a list of extensions. A single
extension is written as a plain string. A list is useful when a project mixes conventions for
a given file type (e.g. source files named with both `.c` and `.C`).

Ceedling searches for and collects files under any extension in the list.

## Example `:extension` YAML

```yaml
:extension:
  :source: .cc       # A single extension
  :header:           # A list of extensions
    - .h
    - .H
  :executable: .bin
```

## `:header`

C header files

**Default**: .h

## `:source`

C code files (whether source or test files)

**Default**: .c

## `:assembly`

Assembly files (contents wholly assembler instructions)

**Default**: .s

## `:object`

Resulting binary output of C code compiler (and assembler)

**Default**: .o

## `:executable`

Binary executable to be loaded and executed upon target hardware

**Default**: .exe or .out (Win or Linux)

## `:testpass`

Test results file (not likely to ever need a redefined value)

**Default**: .pass

## `:testfail`

Test results file (not likely to ever need a redefined value)

**Default**: .fail

## `:dependencies`

File containing make-style dependency rules created by the `gcc` preprocessor

**Default**: .d

<br/><br/>
