# 🌱 Ceedling Known Issues

Known issues are complemented by three other documents:

1. 🔊 **[Release Notes](ReleaseNotes.md)** for announcements, education, and acknowledgements.
1. 🪵 **[Changelog](Changelog.md)** for a structured list of additions, fixes, changes, and removals.
1. 💔 **[Breaking Changes](BreakingChanges.md)** for a list of impacts to existing Ceedling projects.

---

## 1.1.0 — 2026-07-16

1. The new internal pipeline as of 1.0.0 that allows builds to be parallelized and configured per-test-executable can mean a fair amount of duplication of steps. A header file may be mocked identically multiple times. The same source file may be compiled identically multiple times. The speed gains due to parallelization help make up for this. Future releases will concentrate on optimizing away duplication of build steps.
1. While header file search paths are now customizable per executable, this currently only applies to the search paths the compiler uses. Distinguishing test files or header files of the same name in different directories for test runner and mock generation respectively continues to rely on educated guesses in Ceedling code.
1. All header files needed for test compilation must be within the `:includes` path collection. Relative paths in include directives that extend outside the path collection will cause build problems.
1. Any path for a C file specified with `TEST_SOURCE_FILE(...)` is in relation to **_project root_** — that is, from where you execute `ceedling` at the command line. If you move source files or change your directory structure, many of your `TEST_SOURCE_FILE(...)` calls may need to be updated. A more flexible and dynamic approach to path handling will come in a future update.
1. The Bullseye code coverage plugin has been temporarily disabled as of 1.0.0. The makers of Bullseye have generously provided a license for development, and the plugin will be available in the next minor release.

---

## 1.0.0 — 2025-01-01

1. The new internal pipeline that allows builds to be parallelized and configured per-test-executable can mean a fair amount of duplication of steps. A header file may be mocked identically multiple times. The same source file may be compiled identically multiple times. The speed gains due to parallelization help make up for this. Future releases will concentrate on optimizing away duplication of build steps.
1. While header file search paths are now customizable per executable, this currently only applies to the search paths the compiler uses. Distinguishing test files or header files of the same name in different directories for test runner and mock generation respectively continues to rely on educated guesses in Ceedling code.
1. All header files needed for test compilation must be within the `:includes` path collection. Relative paths in include directives that extend outside the path collection will cause build problems.
1. System header includes `#include <system.h>` may not be properly distinguished from user includes `#include "user.h"` in many test preprocessing scenarios.
1. Any path for a C file specified with `TEST_SOURCE_FILE(...)` is in relation to **_project root_** — that is, from where you execute `ceedling` at the command line. If you move source files or change your directory structure, many of your `TEST_SOURCE_FILE(...)` calls may need to be updated. A more flexible and dynamic approach to path handling will come in a future update.
1. Ceedling’s many test preprocessing improvements are not presently able to preserve Unity’s special `TEST_CASE()` and `TEST_RANGE()` features. However, preprocessing of test files is much less frequently needed than preprocessing of mockable header files. Test preprocessing can now be configured to enable only one or the other. As such, these advanced Unity features can still be used in even sophisticated projects.
1. The Bullseye code coverage plugin has been temporarily disabled until a license can be procured that will allow updates and improvements.
