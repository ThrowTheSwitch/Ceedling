# Ceedling Cipher Quest Project

A small field-text toolkit for the discerning intelligence agent. Cipher Quest
encodes messages, decodes intercepted communications, and analyzes text — but
only if you tell it which tools to pack.

This example project illustrates:

- **Test builds and release builds of the same project** using Ceedling
- **Per-test-file symbol definitions** via the `:defines` matcher section in
  `project.yml`
- **Conditional compilation** with `#ifdef` to enable/disable feature modules
- **Release build variants** driven by mixins — the project file itself has no
  release symbols; each variant is supplied externally
- **A compile-time `#error`** that prevents building a featureless release binary

This project is limited to string manipulation and relies solely on basic 
assertions for its test suite (i.e. no mocks or Partials).

---

## Project Structure

```
cipher_quest/
├── project.yml          # Ceedling configuration
├── mixin/               # Release build variant mixins
│   ├── release_rot13.yml
│   ├── release_caesar.yml
│   ├── release_analyze.yml
│   └── release_full.yml
├── src/
│   ├── main.c           # CLI entry point (NOT unit tested)
│   ├── text_utils.c/.h  # Core string utilities (always compiled)
│   ├── cipher.c/.h      # Cipher operations (CIPHER_ROT13 / CIPHER_CAESAR)
│   └── analyzer.c/.h    # Text analysis (ANALYZER_ENABLED)
└── test/
    ├── TestTextUtils.c      # Tests core utilities — needs only TEST
    ├── TestCipherRot13.c    # Tests ROT13    — needs TEST + CIPHER_ROT13
    ├── TestCipherCaesar.c   # Tests Caesar   — needs TEST + CIPHER_CAESAR
    └── TestAnalyzer.c       # Tests analysis — needs TEST + ANALYZER_ENABLED
```

---

## Feature Symbols

| Symbol             | Enables                              |
|--------------------|--------------------------------------|
| `CIPHER_ROT13`     | ROT13 encode/decode                  |
| `CIPHER_CAESAR`    | Caesar cipher encrypt/decrypt        |
| `ANALYZER_ENABLED` | Character count, frequency, palindrome detection |

Both `CIPHER_ROT13` and `CIPHER_CAESAR` can be defined simultaneously.
If none of the three symbols is defined at compile time, `main.c` raises
a `#error` to prevent building a binary that can't do anything useful.

---

## Test Build

Run all unit tests (no feature symbols needed beyond `TEST`, which Ceedling
applies automatically via the `'*'` matcher in `project.yml`):

```sh
ceedling test:all
```

Each test file that exercises a conditionally compiled feature gets its
own symbol via the `:defines` matcher in `project.yml`:

```yaml
:defines:
  :test:
    '*':
      - TEST
    :TestCipherRot13:
      - CIPHER_ROT13
    :TestCipherCaesar:
      - CIPHER_CAESAR
    :TestAnalyzer:
      - ANALYZER_ENABLED
```

This means each test executable sees only the symbols it needs. The ROT13
tests compile `cipher.c` with `CIPHER_ROT13` defined; the Caesar tests
compile it with `CIPHER_CAESAR`; neither affects the other.

You can also run a single test file:

```sh
ceedling test:TestCipherRot13
ceedling test:TestAnalyzer
```

Or all tests matching a pattern:

```sh
ceedling test:pattern[Cipher]
```

---

## Release Build

The `:defines: :release:` section in `project.yml` is intentionally empty.
A plain `ceedling release` will **fail** at the compilation of `main.c` with
a descriptive error:

```
error: "cipher_quest: No feature defined. An agent needs tools. ..."
```

To build a release binary, supply one or more feature symbols via a mixin.

### Using a mixin file (optional `@` sigil)

```sh
# ROT13 variant
ceedling release --mixin=@mixin/release_rot13.yml

# Caesar cipher variant
ceedling release --mixin=@mixin/release_caesar.yml

# Analysis variant
ceedling release --mixin=@mixin/release_analyze.yml

# Full-featured: All capabilities enabled
ceedling release --mixin=@mixin/release_full.yml
```

Mixin files are simple YAML fragments that merge into the project
configuration. For example, `mixin/release_rot13.yml` contains:

```yaml
:defines:
  :release:
    - CIPHER_ROT13
```

Ceedling deep-merges this with `project.yml`, adding `CIPHER_ROT13` to the
release compilation flags without modifying the base project file.

### Using inline YAML mixin (`=` sigil)

Rather than referencing a file, YAML can be supplied directly on the command
line using the `=` sigil prefix. Quote the value to protect YAML special
characters (colons, brackets, spaces) from shell interpretation:

```sh
# ROT13 variant
ceedling release --mixin "=:defines: {release: [CIPHER_ROT13]}"

# Caesar cipher variant
ceedling release --mixin "=:defines: {release: [CIPHER_CAESAR]}"

# All features enabled
ceedling release --mixin "=:defines: {release: [CIPHER_ROT13, CIPHER_CAESAR, ANALYZER_ENABLED]}"
```

Multiple `--mixin` values can be combined and are processed left-to-right:

```sh
ceedling release --mixin @mixin/release_rot13.yml --mixin "=:project: {build_root: ci_build}"
```

---

## Example Session

```sh
# Build and run with ROT13 enabled
ceedling release --mixin=mixin/release_rot13.yml
./build/release/cipher_quest.out rot13 "Attack at dawn"
# => Nggnpx ng qnja

./build/release/cipher_quest.out rot13 "Nggnpx ng qnja"
# => Attack at dawn

# Build with all features and try the analyzer
ceedling release --mixin=mixin/release_full.yml
./build/release/cipher_quest.out ispalindrome "A man a plan a canal Panama"
# => Yes, it is a palindrome.

./build/release/cipher_quest.out caesar 13 "Hello, World!"
# => Uryyb, Jbeyq!
```
