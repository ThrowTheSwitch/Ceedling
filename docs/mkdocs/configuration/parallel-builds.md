# Parallel Build Steps

Beginning with version 1.0.0, Ceedling supports parallelization of tasks.

## Configuration

To enable parallel builds, simply configure either or both of the following in
your project configuration:

* [`:project` ↳ `:compile_threads`](reference/project.md#compile_threads)
* [`:project` ↳ `:test_threads`](reference/project.md#test_threads)

These two settings allow you to separate build step parallelism from test suite
execution parallelism. Why? A core reason is because some emulator setups
necessary for test suite execution do not allow multiple instances running
simultaneously.

## Operating System restrictions

!!! warning "Operating Systems security protections can limit parallelism"

Modern versions of macOS and Windows both include security gatekeeping that can
limit Ceedling’s ability to achieve speedups and true parallelism. These
products can:

1. Execute first-run security checks on newly built, unsgined executables
(such as components of a test suite) that greatly slow down execution.
1. Force one-at-a-time execution for any unsigned software attempting to 
spawn multiple processes simultaneously.

Signing the executables Ceedling generates is wildly complex and maybe even
practically impossible.

A current limitation of Ceedling since 1.0.0 also contributes to these
bottlenecks. Namely, with the release of 1.0.0 Ceedling lost “delta” builds —
the ability to only regenerate components of a test suite that have changed.
This means Ceedling’s test suites are fully rebuilt each time with OS first-run
security checks to fire at run time. Future versions of Ceedling will restore
this ability.

!!! tip "Configuring OS security restrictions"
    Read up on your Operating System’s options for configuring the restrictions 
    noted above. For instance, you may be able to configure certain exceptions 
    for your terminal application that cascade to benefit Ceedling’s parallelism.

## Parallel execution in Ruby

You may have heard that Ruby is actually only single-threaded or may know of its
Global Interpreter Lock (GIL) that prevents parallel execution
[^python-note]. This is true but not the whole story.

To oversimplify a complicated subject, the Ruby implementations typically used
to run Ceedling do afford concurrency and true parallelism speedups but only in
certain circumstances. It so happens that these circumstances are precisely the
workload that Ceedling manages.

“Mainstream” Ruby implementations — not JRuby[^jruby-note], for example — offer
 the following exceptions and abilities of which Ceedling takes advantage.

### I/O operations thread context switching

Since version 1.9, Ruby supports native threads and not only green threads.
However, native threads are limited by the GIL to executing one at a time
regardless of the number of cores in your processor. But, the key exception
here is the GIL is “relaxed” for I/O operations.

When a native thread blocks for I/O, Ruby allows the OS scheduler to context
switch to a thread ready to execute. This is the original benefit of threads
when they were first developed back when CPUs contained a single core and
multi-processor systems were rare and special.

Ceedling does a fair amount of file and standard stream I/O in its pure Ruby
code. Thus, when multiple threads are enabled in the project configuration,
execution can speed up for these operations because Ruby’s GIL allows those I/O
operations to execute with true parallelism.

### Process spawning

Ruby’s process spawning abilities have always mapped directly to OS
capabilities. When a processor has multiple cores available, the OS tends to
spread multiple child processes across those cores in true parallel execution.

Much of Ceedling’s workload is executing a tool — such as a compiler — in a
child process. With multiple threads enabled, each thread can spawn a child
process for a build tool used by a build step. These child processes can be
spread across multiple cores in true parallel execution.

[^python-note]: Python and most other scripting-style languages rely on the
Global Interpreter Lock concept for managing parallelism. A class of languages
that includes Go, Rust, and Java fully support true parallelism.

[^jruby-note]: JRuby implements the Ruby language by way of an underlying Java
implementation. This allows Ruby to run in certain contexts it might not
otherwise be able to — particularly in Enterprise systems. Ruby parallelism in
JRuby is built atop Java’s true, native parallelism. Taking advantage of JRuby
requires certain customization of the Ruby language, and Ceedling has never
been tested for JRuby support.