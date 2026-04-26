# Ceedling Plugins

Ceedling includes a number of plugins. See the collection of built-in [plugins](index.md)
or consult the list with summaries and links to documentation in the subsection 
that follows. Each plugin page includes full documentation of its 
capabilities and configuration options.

To enable built-in plugins or your own custom plugins, see the documentation for
the [`:plugins` section](../configuration-reference.md#plugins-ceedling-extensions) in Ceedling project configuration options.

Many users find that the handy-dandy [Command Hooks plugin](command-hooks.md) 
is often enough to meet their needs. This plugin allows you to connect your own
scripts and tools to Ceedling build steps.

As mentioned, you can create your own plugins. See the [guide](../development/plugin-development-guide.md) 
for how to create custom plugins.

## Ceedling's built-in plugins, a directory

### Ceedling plugin `report_tests_pretty_stdout`

[This plugin](report-tests-pretty-stdout.md) is meant to be the default for
printing test results to the console. Without it, readable test results are
still produced but are not nicely formatted and summarized.

Plugin output includes a well-formatted list of summary statistics, ignored and
failed tests, and any extraneous output (e.g. `printf()` statements or
simulator memory errors) collected from executing the test fixtures.

Alternatives to this plugin are:
 
 * `report_tests_ide_stdout`
 * `report_tests_gtestlike_stdout`

Both of the above write to the console test results with a format that is useful
to IDEs generally in the case of the former, and GTest-aware reporting tools in
the case of the latter.

### Ceedling plugin `report_tests_ide_stdout`

[This plugin](report-tests-ide-stdout.md) prints to the console test results
formatted similarly to `report_tests_pretty_stdout` with one key difference.
This plugin's output is formatted such that an IDE executing Ceedling tasks can
recognize file paths and line numbers in test failures, etc.

This plugin's formatting is often recognized in an IDE's build window and
automatically linked for file navigation. With such output, you can select a
test result in your IDE's execution window and jump to the failure (or ignored
test) in your test file (more on using [IDEs] with Ceedling, Unity, and
CMock).

If enabled, this plugin should be used in place of 
`report_tests_pretty_stdout`.

[IDEs]: https://www.throwtheswitch.org/ide

### Ceedling plugin `report_tests_teamcity_stdout`

[TeamCity] is one of the original Continuous Integration server products.

[This plugin](report-tests-teamcity-stdout.md) processes test results into TeamCity
service messages printed to the console. TeamCity's service messages are unique
to the product and allow the CI server to extract build steps, test results,
and more from software builds if present.

The output of this plugin is useful in actual CI builds but is unhelpful in
local developer builds. See the plugin's documentation for options to enable
this plugin only in CI builds and not in local builds.

[TeamCity]: https://jetbrains.com/teamcity

### Ceedling plugin `report_tests_gtestlike_stdout`

[This plugin](report-tests-gtestlike-stdout.md) collects test results and prints
them to the console in a format that mimics [Google Test's output][gtest-sample-output]. 
Google Test output is both human readable and recognized
by a variety of reporting tools, IDEs, and Continuous Integration servers.

If enabled, this plugin should be used in place of
`report_tests_pretty_stdout`.

[gtest-sample-output]:
https://subscription.packtpub.com/book/programming/9781800208988/11/ch11lvl1sec31/controlling-output-with-google-test

### Ceedling plugin `command_hooks`

[This plugin](command-hooks.md) provides a simple means for connecting Ceedling's build events to
Ceedling tool entries you define in your project configuration (see `:tools`
documentation). In this way you can easily connect your own scripts or command
line utilities to build steps without creating an entire custom plugin.

### Ceedling plugin `module_generator`

A pattern emerges in day-to-day unit testing, especially in the practice of
Test-Driven Development. Again and again, one needs a triplet of a source
file, header file, and test file — scaffolded in such a way that they refer to
one another.

[This plugin](module-generator.md) allows you to save precious minutes by creating
these templated files for you with convenient command line tasks.

### Ceedling plugin `fff`

The Fake Function Framework, [FFF], is an alternative approach to [test doubles][test-doubles] 
than that used by CMock.

[This plugin](fff.md) replaces Ceedling generation of CMock-based mocks and
stubs in your tests with FFF-generated fake functions instead.

[FFF]: https://github.com/meekrosoft/fff
[test-doubles]: https://blog.pragmatists.com/test-doubles-fakes-mocks-and-stubs-1a7491dfa3da

### Ceedling plugin `beep`

[This plugin](beep.md) provides a simple audio notice when a test build completes suite
execution or fails due to a build error. It is intended to support developers
running time-consuming test suites locally (i.e. in the background).

The plugin provides a variety of options for emitting audio notificiations on
various desktop platforms.

### Ceedling plugin `bullseye`

[This plugin](bullseye.md) adds additional Ceedling tasks to execute tests
with code coverage instrumentation provided by the commercial code coverage
tool provided by [Bullseye]. The Bullseye tool provides visualization and report
generation from the coverage results produced by an instrumented test suite.

[Bullseye]: http://www.bullseye.com

### Ceedling plugin `gcov`

[This plugin](gcov.md) adds additional Ceedling tasks to execute tests with GNU code
coverage instrumentation. Coverage reports of various sorts can be generated
from the coverage results produced by an instrumented test suite.

This plugin manages the use of up to three coverage reporting tools. The GNU
[gcov] tool provides simple coverage statitics to the console as well as to the
other supported reporting tools. Optional Python-based [GCovr] and .Net-based
[ReportGenerator] produce fancy coverage reports in XML, JSON, HTML, etc.
formats.

[gcov]: http://gcc.gnu.org/onlinedocs/gcc/Gcov.html
[GCovr]: https://www.gcovr.com/
[ReportGenerator]: https://reportgenerator.io

### Ceedling plugin `report_tests_log_factory`

[This plugin](report-tests-log-factory.md) produces any or all of three useful test
suite reports in JSON, JUnit, or CppUnit format. It further provides a
mechanism for users to create their own custom reports with a small amount of
custom Ruby rather than a full plugin.

### Ceedling plugin `report_build_warnings_log`

[This plugin](report-build-warnings-log.md) scans the output of build tools for console
warning notices and produces a simple text file that collects all such warning
messages.

### Ceedling plugin `report_tests_raw_output_log`

[This plugin](report-tests-raw-output-log.md) captures extraneous console output
generated by test executables — typically for debugging — to log files named
after the test executables.

### Ceedling plugin `subprojects`

[This plugin](subprojects.md) supports subproject release builds of static
libraries. It manages differing sets of compiler flags and linker flags that
fit the needs of different library builds.

### Ceedling plugin `dependencies`

[This plugin](dependencies.md) manages release build dependencies including
fetching those dependencies and calling a given dependency's build process.
Ultimately, this plugin generates the components needed by your Ceedling
release build target.

### Ceedling plugin `compile_commands_json_db`

[This plugin](compile-commands-json-db.md) creates a [JSON Compilation Database][json-compilation-database]. 
This file is useful to [any code editor or IDE][lsp-tools] that implements 
syntax highlighting, etc. by way of the LLVM project's [`clangd`][clangd] 
Language Server Protocol conformant language server.

[lsp-tools]: https://microsoft.github.io/language-server-protocol/implementors/tools/
[clangd]: https://clangd.llvm.org
[json-compilation-database]: https://clang.llvm.org/docs/JSONCompilationDatabase.html

<br/>
