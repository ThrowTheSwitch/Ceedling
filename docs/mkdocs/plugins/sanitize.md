# Sanitize

Adds Ceedling tasks to build and run test executables with the compiler’s
sanitizers. [AddressSanitizer] (ASan), [UndefinedBehaviorSanitizer] (UBSan),
and [LeakSanitizer] (LSan) find memory errors, undefined behavior, and leaks
while your tests run.

The Sanitize plugin creates a duplicate test build with `sanitize:` command
line plugin tasks. [This is intentional and needed](index.md#understanding-plugin-build-duplication).

!!! note
    A `sanitize:` task is a [delta build](../getting-started/builds.md).
    This plugin maintains its own dependency cache. A test executable will be
    rebuilt the first time you run a `sanitize:` build.

---

## Plugin overview

!!! note "Linux and macOS"
    The sanitizers run on Linux with GCC or Clang and on macOS with Clang.
    Leak detection is Linux only. The plugin is not supported on Windows.

    Enabling this plugin on a platform without sanitizers does not affect your
    other builds. Only a `sanitize:` task requires them.

The Sanitize plugin compiles and links your tests with the sanitizers, then
runs each test executable with the sanitizers’ runtime options set for it
alone. Each sanitizer reports what it finds as the test runs.

The plugin provides invocation modes mirroring standard `test:` tasks.

- **Whole test suite**: `ceedling sanitize:all` builds and runs every test
  executable with sanitizers.
- **Single test file**: `ceedling sanitize:<filename>` builds and runs one.

By default a sanitizer stops a test at its first finding, and any finding fails
the build. Each test’s sanitizer reports are saved to a log file of its own.

Sanitizer flags only reach the builds this plugin instruments. Builds from
other plugins, such as `gcov:` and `valgrind:`, are never instrumented.

## Set up

### Toolchain

The sanitizers are part of GCC and Clang. No separate installation is needed
where your compiler provides them.

- **Linux**: GCC or Clang with their sanitizer runtimes. Some distributions
  package these separately (e.g. `libasan` and `libubsan`).
- **macOS**: The Clang that ships with Xcode or the Command Line Tools.

The plugin runs each test executable through `env`, which sets the sanitizers’
runtime options. `env` is standard on Linux and macOS.

The `-plugins` variants of the [_MadScienceLab_ Docker images][docker-hub]
come with a ready toolchain.

[docker-hub]: https://hub.docker.com/repository/docker/throwtheswitch/

### Enable the plugin

Enable the plugin by adding `sanitize` to the enabled plugins list in your
project configuration:

```yaml
:plugins:
  :enabled:
    - sanitize
```

## Configuration

The plugin’s defaults turn on ASan and UBSan, stop a test at its first finding,
check for leaks where supported, and fail the build on any finding. Change any
of these under an optional `:sanitize` section in your project configuration.

### Default configuration

```yaml
:sanitize:
  :sanitizers:
    - :address
    - :undefined
  :recover: FALSE
  :detect_leaks: TRUE
  :test_builds: FALSE
  :fail_build: TRUE
  :reports: []
  :runtime_options:
    :asan: []
    :ubsan: []
    :lsan: []
  :flags:
    :compile: []
    :link: []
```

### `:sanitizers:`

The sanitizers to build with. Any of `:address`, `:undefined`, and `:leak`.
Names written as strings, such as `address`, work too.

```yaml
:sanitize:
  :sanitizers:
    - :undefined
```

ASan’s runtime includes leak detection, so `:leak` adds nothing beside
`:address`. List `:leak` alone for leak detection without ASan.

**Default:** `[:address, :undefined]`

### `:recover:`

When `false` (the default), a sanitizer stops a test at its first finding.
When `true`, the test keeps running and each finding is reported.

```yaml
:sanitize:
  :recover: true
```

**Default:** `false`

### `:detect_leaks:`

When `true` (the default), ASan checks for leaks as each test executable exits.
Leak detection is not supported on macOS. There, the plugin disables it with a
notice.

**Default:** `true`

### `:test_builds:`

When `true`, ordinary `test:` builds are built with the sanitizers too. A
`sanitize:` build is always instrumented.

```yaml
:sanitize:
  :test_builds: true
```

**Default:** `false`

### `:fail_build:`

When `true` (the default), any sanitizer finding fails the build. When `false`,
findings are still logged and saved, but the build is not failed for them.

A test a sanitizer stopped is still a failing test either way.

**Default:** `true`

### `:reports:`

Reports of a build’s findings, written for each instrumented build. Any of
`:text`, `:json`, and `:sarif`.

- **`:text`** collects each finding’s report as the sanitizer printed it.
- **`:json`** lists each finding’s test, sanitizer, kind, file, line, and
  message.
- **`:sarif`** writes [SARIF] 2.1.0 for code scanning services such as GitHub
  code scanning. Each finding is an error.

```yaml
:sanitize:
  :reports:
    - :text
    - :sarif
```

The JSON and SARIF reports are written even for a build without findings, so a
CI step always finds its file. An empty SARIF run tells a code scanning service
that earlier findings are gone.

**Default:** `[]` (the text report alone)

### `:runtime_options:`

Extra runtime options for each sanitizer, appended to the plugin’s own. Each
entry is one `name=value` option.

```yaml
:sanitize:
  :runtime_options:
    :asan:
      - strict_string_checks=1
    :ubsan:
      - report_error_type=1
```

The plugin sets these options itself:

| Variable | Options |
|---|---|
| `ASAN_OPTIONS` | `halt_on_error`, `exitcode=0`, and `detect_leaks` (Linux) |
| `UBSAN_OPTIONS` | `halt_on_error`, `print_stacktrace=1`, and `exitcode=0` |
| `LSAN_OPTIONS` | `exitcode=0`, when the leak sanitizer runs without ASan |

`exitcode=0` lets the plugin judge each run by what the sanitizers report rather
than by their exit codes. See [How findings are reported](#how-findings-are-reported).

**Default:** none

### `:flags:`

Extra compile and link flags for instrumented builds. They follow the plugin’s
own `-fsanitize`, `-fno-omit-frame-pointer`, and `-g`, plus
`-fno-sanitize-recover=all` unless [`:recover:`](#recover) is on.

```yaml
:sanitize:
  :flags:
    :compile:
      - -O1
    :link:
      - -static-libasan
```

**Default:** none

### Flags and defines for the `sanitize:` build

A `sanitize:` build is a build context of its own. Like `:test`, it accepts
[`:flags`](../configuration/reference/flags.md) and
[`:defines`](../configuration/reference/defines.md) entries, matchers included.
Without its own entries for an operation, a `sanitize:` build uses `:test`’s.

```yaml
:defines:
  :sanitize:
    - SANITIZED_BUILD
```

## Usage

The Sanitize plugin follows the conventions of `test:` tasks.

### Run sanitizers for all tests

```shell
$ ceedling sanitize:all
```

### Run sanitizers for a single test file

Pass the test filename, no path:

```shell
$ ceedling sanitize:test_my_module.c
```

You can also pass just the source filename. Ceedling locates the corresponding
test file:

```shell
$ ceedling sanitize:my_module.c
```

## How findings are reported

A sanitizer’s finding is reported where you would look for a test failure.

- **A halted test** fails, named by its finding. When a sanitizer stops a test,
  the test executable ends before Unity prints its summary, and Ceedling treats
  that as a crash. The crash notice names the sanitizer, the kind of finding,
  its location, and the test’s log. It replaces Ceedling’s generic crash notice
  and its backtrace advice:

  ```
  ☠️ ERROR: Test executable `test_buffer.out` was stopped by a sanitizer finding.
  > AddressSanitizer heap-buffer-overflow at test/test_buffer.c:21
  > Boom log: build/artifacts/sanitize/sanitize/test_buffer.log
  ```

  The test’s failure message carries the same on one line:

  ```
  AddressSanitizer heap-buffer-overflow at test/test_buffer.c:21 (Boom log: build/artifacts/sanitize/sanitize/test_buffer.log)
  ```

- **A leak** is a finding, not a test failure. Leaks are found as a test
  executable exits, after every test case has reported. Your test results stay
  as Unity reported them, and the leak is logged and counted.

- **A crash no sanitizer reported** keeps Ceedling’s usual crash message.

Each finding is also logged as the test runs, except one a crash notice
names. With [`:fail_build:`](#fail_build) enabled, the build failure summary
counts the findings and names the reports written:

```
 • [SANITIZE] Sanitizers found 2 problems in 2 tests. See the reports in build/artifacts/sanitize/sanitize: sanitize.log, sanitize.json.
```

### Example console output

These excerpts come from real runs. Build progress lines are left out.

A halted test, with `:reports` set to `[:text, :json, :sarif]`:

```
☠️ ERROR: Test executable `test_nosanitize_heap_buffer_overflow.out` was stopped by a sanitizer finding.
> AddressSanitizer heap-buffer-overflow at test/test_nosanitize_heap_buffer_overflow.c:29
> Boom log: build/artifacts/sanitize/sanitize/test_nosanitize_heap_buffer_overflow.log

SANITIZE: FAILED TEST SUMMARY
[test/test_nosanitize_heap_buffer_overflow.c]
  Test: test_writes_past_its_buffer
  At line (27): "AddressSanitizer heap-buffer-overflow at test/test_nosanitize_heap_buffer_overflow.c:29 (Boom log: build/artifacts/sanitize/sanitize/test_nosanitize_heap_buffer_overflow.log)"

SANITIZE: ❌ OVERALL TEST SUMMARY
TESTED:  2
PASSED:  1
FAILED:  1
IGNORED: 0

❌ BUILD FAILURE SUMMARY
 • [SANITIZE] Unit test failures
 • [SANITIZE] Sanitizers found 1 problem in 1 test. See the reports in build/artifacts/sanitize/sanitize: sanitize.log, sanitize.json, sanitize.sarif.
```

A leak. Every test passes, and the leak alone fails the build. The test’s
own output section shows the sanitizer’s report:

```
🪲 ERROR: test_nosanitize_leak: LeakSanitizer memory-leak at test/test_nosanitize_leak.c:32 ➡️ see build/artifacts/sanitize/sanitize/test_nosanitize_leak.log

SANITIZE: TEST OUTPUT
[test/test_nosanitize_leak.c]
  - "==456==ERROR: LeakSanitizer: detected memory leaks"
  - "Direct leak of 32 byte(s) in 1 object(s) allocated from:"
  - "    #1 0x55f0b16d72e9 in test_loses_its_allocation test/test_nosanitize_leak.c:32"
  - "SUMMARY: AddressSanitizer: 32 byte(s) leaked in 1 allocation(s)."

SANITIZE: ✅ OVERALL TEST SUMMARY
TESTED:  2
PASSED:  2
FAILED:  0
IGNORED: 0

❌ BUILD FAILURE SUMMARY
 • [SANITIZE] Sanitizers found 1 problem in 1 test. See the reports in build/artifacts/sanitize/sanitize: sanitize.log.
```

A clean build adds nothing to the test summary, even when JSON or SARIF
reports are written.

On macOS, a leak sanitizer or `:detect_leaks` logs this warning at startup:

```
⚠️ WARNING: Leak detection is not supported on macOS and has been disabled.
```

### Backtraces

With [`:use_backtrace`](../configuration/reference/project.md#use_backtrace)
set to `:simple`, each crashed test executable reruns one test case at a time.
The reruns run with the sanitizers’ options too, so each crashed test case is
named by its own finding.

`:gdb` backtraces fall back to `:simple` in instrumented builds, with a notice.
The leak sanitizer cannot run under a debugger, and a sanitizer’s own report
already includes the stack.

## Artifacts

Each test with findings has a log of its sanitizer reports:

```
build/artifacts/sanitize/sanitize/<test_name>.log
```

The configured reports are written beside the logs:

```
build/artifacts/sanitize/sanitize/sanitize.log
build/artifacts/sanitize/sanitize/sanitize.json
build/artifacts/sanitize/sanitize/sanitize.sarif
```

With `:test_builds` enabled, an ordinary `test:` build writes its logs and
reports to `build/artifacts/sanitize/test/`.

The artifacts are included in `ceedling clean` targets.

## Interpreting results

Each sanitizer report begins with what it found and where, followed by the
stack of calls that led there. Common findings include:

| Sanitizer | Finding | Description |
|---|---|---|
| ASan | `heap-buffer-overflow` | Access past the end of a heap allocation |
| ASan | `stack-buffer-overflow` | Access past the end of a local array |
| ASan | `heap-use-after-free` | Access to memory already freed |
| ASan | `double-free` | Memory freed twice |
| UBSan | `runtime error: …` | Undefined behavior, such as signed overflow, an out-of-range shift, or a null pointer load |
| LSan | `detected memory leaks` | Memory allocated and never freed |

A finding’s location is the first stack frame in your code, past the
sanitizer’s own runtime.

## Other plugins

A test executable built with sanitizers cannot run under Valgrind. Valgrind
builds are never instrumented by this plugin. A `valgrind:` build whose own
flags carry `-fsanitize`, such as flags it uses from `:flags` ↳ `:test`, stops
with a message naming them.

Coverage builds from the Gcov and Bullseye plugins are not instrumented either.
Sanitizers and coverage instrumentation each alter the code they build, and are
kept apart in their own builds.

[AddressSanitizer]: https://clang.llvm.org/docs/AddressSanitizer.html
[UndefinedBehaviorSanitizer]: https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html
[LeakSanitizer]: https://clang.llvm.org/docs/LeakSanitizer.html
[SARIF]: https://sarifweb.azurewebsites.net

<br/><br/>
