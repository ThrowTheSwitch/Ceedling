# Valgrind

Adds Ceedling tasks to run test executables under [Valgrind] memory error
detection, helping catch memory leaks, invalid memory accesses, and
use-after-free bugs in your C code.

## Plugin overview

The Valgrind plugin integrates [Valgrind] dynamic analysis into Ceedling,
building and then running test executables under Valgrind's Memcheck tool.
It provides two invocation modes:

- **Whole test suite**: By running `ceedling valgrind:all`, all test
  executables are built and then each is run under Valgrind. A separate log
  file is produced for each test executable in `build/artifacts/valgrind/`.
- **Single test file**: By running `ceedling valgrind:<filename>`, a single
  test executable is built and run under Valgrind, producing one log file.

The plugin builds test executables in the same way as the standard `test`
tasks and then hands each executable off to Valgrind, passing it configurable
arguments. The Valgrind exit code is forwarded so the build fails when
Valgrind detects an error.

!!! note "Linux only"
    Valgrind runs on Linux and other Unix-like systems. It is not available
    on Windows or macOS (ARM).

## Setup

Install Valgrind from your Linux distribution's package manager:

```shell
sudo apt-get install valgrind   # Debian / Ubuntu
sudo dnf install valgrind       # Fedora / RHEL
```

Or build from source from [valgrind.org/downloads/](https://valgrind.org/downloads/).

Enable the plugin by adding `valgrind` to the enabled plugins list in your
`project.yml` file:

```yaml
:plugins:
  :enabled:
    - valgrind
```

## Configuration

The plugin ships with sensible defaults that enable full leak checking and
treat any detected error as a build failure. You can override the Valgrind
tool configuration in your `project.yml` under the `:tools` section.

### Default tool configuration

The default tool entry used by the plugin is:

```yaml
:tools:
  :valgrind:
    :executable: valgrind
    :arguments:
      - --leak-check=full
      - --show-leak-kinds=all
      - --track-origins=yes
      - --errors-for-leak-kinds=all
      - --exit-on-first-error=yes
      - --error-exitcode=1
      - ${1}
```

`${1}` is replaced at runtime with the path to the test executable being
analyzed.

### Overriding Valgrind arguments

To use a different Valgrind binary or pass different flags, override the
`:valgrind` tool entry:

```yaml
:tools:
  :valgrind:
    :executable: valgrind
    :arguments:
      - --leak-check=full
      - --show-leak-kinds=all
      - --track-origins=yes
      - --errors-for-leak-kinds=all
      - --exit-on-first-error=yes
      - --error-exitcode=1
      - --suppressions=my_suppressions.supp
      - ${1}
```

### Selecting a custom Valgrind binary

You can also select the Valgrind binary via the `VALGRIND` environment
variable without changing `project.yml`:

```shell
VALGRIND=/usr/local/bin/valgrind ceedling valgrind:all
```

## Usage

### Run Valgrind for all tests

Build all test executables and run each under Valgrind:

```shell
$ ceedling valgrind:all
```

### Run Valgrind for a single test file

Build and run Valgrind for one test file (pass the filename, no path):

```shell
$ ceedling valgrind:test_my_module.c
```

You can also pass just the source filename; Ceedling will locate the
corresponding test file automatically:

```shell
$ ceedling valgrind:my_module.c
```

## Artifacts

Each test executable produces a Valgrind log file at:

```
build/artifacts/valgrind/<test_name>.log
```

For example, running `ceedling valgrind:test_my_module.c` produces:

```
build/artifacts/valgrind/test_my_module.log
```

These log files contain the full Valgrind Memcheck output, including any
detected memory errors, leak summaries, and (with `--track-origins=yes`)
the origin of uninitialized values.

The log files are included in `ceedling clean` targets.

## Interpreting results

A non-zero exit from Valgrind (controlled by `--error-exitcode=1`) causes
the Ceedling task to fail. The Valgrind log file for the failing test
contains the full error details.

To review the log for a specific test:

```shell
cat build/artifacts/valgrind/test_my_module.log
```

Common Valgrind findings include:

| Finding | Description |
|---------|-------------|
| `definitely lost` | Memory was allocated but never freed — a confirmed leak |
| `indirectly lost` | Memory reachable only through another leaked block |
| `Invalid read/write` | Access outside allocated memory bounds |
| `Use of uninitialised value` | Reading memory before it was written |

[Valgrind]: https://valgrind.org
