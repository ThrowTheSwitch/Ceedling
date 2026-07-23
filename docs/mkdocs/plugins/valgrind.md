# Valgrind

Adds Ceedling tasks to run test executables under [Valgrind] memory error
detection to help find memory leaks, invalid memory accesses, and
use-after-free bugs in your C code.

!!! note
    The Valgrind plugin creates a duplicate test build with `valgrind:` 
    command line plugin tasks. [This is intentional and needed](index.md#understanding-plugin-build-duplication).

---

## Plugin overview

!!! note "Linux only"
    Valgrind runs on Linux and other Unix-like systems. It is not available
    on Windows or macOS (ARM).

The Valgrind plugin integrates [Valgrind] dynamic analysis into Ceedling,
building and then running test executables under Valgrind’s Memcheck tool.

The plugin provides two invocation modes mirroring standard `test:` tasks.

- **Whole test suite**: By running `ceedling valgrind:all`, all test
  executables are built and then each is run under Valgrind. A separate log
  file is produced for each test executable in `build/artifacts/valgrind/`.
- **Single test file**: By running `ceedling valgrind:<filename>`, a single
  test executable is built and run under Valgrind, producing one log file.

The plugin triggers standard `test` task builds but hands each test fixture
executable off to Valgrind along with configurable arguments.

By default the build runs all test binaries to completion and is marked as
failed if any Valgrind memory errors are found. The optional `:fail_build:`
setting can be set to `false` to log errors without failing the build.

## Installation & set up

### Installation

You have at least 3 options for getting the `valgrind` tool working on your
system, including one readymade option.

#### Linux package manager

Install Valgrind from your Linux distribution’s package manager:

```shell
sudo apt-get install valgrind   # Debian / Ubuntu
sudo dnf install valgrind       # Fedora / RHEL
```

#### Build from source

Or build from source from [valgrind.org/downloads/](https://valgrind.org/downloads/).

#### _MadScienceLab_ Docker images

Fully packaged [_MadScienceLab_ Docker images][docker-hub] containing Ruby, 
Ceedling, the GCC toolchain, and more are available. The `-plugins` variants 
of the images come with all of Ceedling’s plugin tools preinstalled.

[docker-hub]: https://hub.docker.com/repository/docker/throwtheswitch/

### Enable the plugin

Enable the plugin by adding `valgrind` to the enabled plugins list in your
project configuration:

```yaml
:plugins:
  :enabled:
    - valgrind
```

## Configuration

The plugin ships with sensible defaults that enable full leak checking. By
default the build runs all test binaries to completion and is marked as failed
if any memory errors are found. Set `:fail_build: false` to log errors without
failing the build.

You can change the Valgrind configuration in your project configuration 
under an optional `:valgrind` section.

### Default configuration

In the default configuration, the Valgrind plugin will run the entire test 
suite, collecting Valgrind reports for each test fixture executable.

By default, the plugin runs with these command line arguments for `valgrind`:

- `--leak-check=full`
- `--show-leak-kinds=all`
- `--track-origins=yes`
- `--errors-for-leak-kinds=all`

### `:arguments:`

The list of flags passed to Valgrind for every test binary. To override the
defaults, redefine the argument list in your project configuration:

```yaml
:valgrind:
  :arguments:
    # A subset of the default arguments
    - "--leak-check=full"
    - "--show-leak-kinds=all"
```

### `:fail_build:`

When `true` (the default), any memory errors are logged immediately after 
running a test executable. After all test binaries complete execution, if 
any memory errors were found across the run, the build is marked as failed 
with a total count of memory errors and test files processed.

When `false`, memory errors are still logged per test binary but the build is
not marked as failed.

```yaml
:valgrind:
  :fail_build: false
```

!!! note "Detection uses log parsing, not Valgrind’s exit code"
    Valgrind’s `--error-exitcode` flag is not used because its exit code would
    overlap with Unity’s own exit code, which equals the number of failing test
    cases. Instead, the plugin parses the `ERROR SUMMARY: N errors` line written
    to the Valgrind log file.

## Usage

The Valgrind plugin follows the conventions of `test:` tasks.

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

See [Valgrind] documentation for more details.

[Valgrind]: https://valgrind.org
