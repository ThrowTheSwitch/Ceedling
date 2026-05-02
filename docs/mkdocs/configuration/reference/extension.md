# `:extension` 

**Filename extensions used to collect lists of files searched in [`:paths`](paths.md)**

Ceedling uses path lists and wildcard matching against filename extensions to collect file lists.

## Example `:extension` YAML

```yaml
:extension:
  :source: .cc
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
