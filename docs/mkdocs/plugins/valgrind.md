# Valgrind

Adds Ceedling tasks to run test executables under [Valgrind] memory error
detection to help find memory leaks, invalid memory accesses, and
use-after-free bugs in your C code.

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

By default the build continues after Valgrind errors so that all log files are
produced. The optional `:halt_on_error:` setting stops the build after the first
test binary whose Valgrind log reports memory errors.

## Setup & installation

### Linux package manager

Install Valgrind from your Linux distribution’s package manager:

```shell
sudo apt-get install valgrind   # Debian / Ubuntu
sudo dnf install valgrind       # Fedora / RHEL
```

### Build from source

Or build from source from [valgrind.org/downloads/](https://valgrind.org/downloads/).

### _MadScienceLab_ Docker images

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
default the build continues after Valgrind errors so that every test binary
runs and produces a log file. Use `:halt_on_error:` to stop early on the
first test fixture executable in the suite with memory errors.

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
    - "--leak-check=full"
    - "--show-leak-kinds=all"
```

### `:halt_on_error:`

When `false` (the default), the build runs all test binaries to completion.
Memory errors appear in the per-binary log files but do not stop the build.
This is often the right choice for an initial analysis run; you get the full
picture of which binaries have problems.

When `true`, the plugin reads the Valgrind log after each test binary finishes
and checks the `ERROR SUMMARY` line. If the error count is greater than zero,
Ceedling raises a build error and halts before running any subsequent test
fixture executables. Valgrind logs created to that point will remain.

```yaml
:valgrind:
  :halt_on_error: true
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
