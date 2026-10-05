# 🌱 Ceedling Known Issues

Known issues are complemented by three other documents:

1. 🔊 **[Release Notes](ReleaseNotes.md)** for announcements, education, and acknowledgements.
1. 🪵 **[Changelog](Changelog.md)** for a structured list of additions, fixes, changes, and removals.
1. 💔 **[Breaking Changes](BreakingChanges.md)** for a list of impacts to existing Ceedling projects.

---

## All versions

- Ceedling installation as a gem (variations of `gem install ceedling`) can fail if installation is allowed to run the default step of RDoc scanning. **Always use `--no-document` to opt out of the RDoc tool’s code scanning during Ceedling installation.** This documentation step is not needed by a Ceedling user, and, more importantly, RDoc can cause installation failures due to bugs or language incompatibilities in RDoc’s custom Ruby language parser. The prepackaged _MadScienceLab_ Docker images avoid this issue entirely.

---

## 1.2.0 — Prerelease

Ceedling 1.2.0 requires Ruby 3+ but only unoficially supports Ruby 4.

1. The new internal pipeline as of 1.0.0 that allows builds to be parallelized and configured per-test-executable can mean a fair amount of duplication of steps. A header file may be mocked identically multiple times. The same source file may be compiled identically multiple times. Delta builds (as of 1.2.0) offer considerable build time savings as do the speedup gains due to parallelization as of 1.0.0. Future releases will optimize away duplication of build steps.
1. An `#include` directive must resolve to a file within your project's configured `:paths` search collection. A path that would resolve outside your configured search paths (e.g. via relative paths beyond search paths or excessive `..` parent-directory segments) is now rejected with a clear, specific error rather than silently causing a confusing downstream build failure.
1. Paths for `TEST_SOURCE_FILE(...)` remain relative to **_project root_** — that is, from where you execute `ceedling` at the command line. If you move source files or change your directory structure, `TEST_SOURCE_FILE(...)` calls referencing moved files will need to be updated.
1. A single test file cannot **mock** two same-named modules using Partials or traditional mocking, even now that it can name each of them by directory. A temporary CMock limitation causes duplicate symbols and missing definitions. A future CMock release will lift the limitation without a change to your test files.

## 1.1.0 — 2026-07-16

1. The new internal pipeline as of 1.0.0 that allows builds to be parallelized and configured per-test-executable can mean a fair amount of duplication of steps. A header file may be mocked identically multiple times. The same source file may be compiled identically multiple times. The speed gains due to parallelization help make up for this. Future releases will concentrate on optimizing away duplication of build steps.
1. While header file search paths are now customizable per executable, this currently only applies to the search paths the compiler uses. Distinguishing test files or header files of the same name in different directories for test runner and mock generation respectively continues to rely on educated guesses in Ceedling code.
1. All header files needed for test compilation must be within the `:includes` path collection. Relative paths in include directives that extend outside the path collection will cause build problems.
1. Any path for a C file specified with `TEST_SOURCE_FILE(...)` is in relation to **_project root_** — that is, from where you execute `ceedling` at the command line. If you move source files or change your directory structure, many of your `TEST_SOURCE_FILE(...)` calls may need to be updated. A more flexible and dynamic approach to path handling will come in a future update.
1. In certain combinations of conditional preprocessing blocks with dependent symbols defined in another file, Ceedling can silently fail to extract computed includes (e.g. `#include SOME_MACRO()`).
1. User includes (`#include "path/user.h"`) from source C files lose their relative path when Partial and mock header files are generated from source. Compilation failures can result from certain uncommon cases involving headers of the same names in different directories and a source file including both such headers.
1. Partial directive macros accept only a bare module name — a filename stem with no path. A project holding two modules of the same name in different directories cannot say which of them a Partial is for, and Ceedling resolves the name the way a compiler resolves a header, selecting the first match among the ordered search paths. Path-qualified Partial macros will arrive in 1.2.0.
1. The automatic vendor copying of Unity, CMock, and CException into a project's build directory can intermittently fail with a file/directory type error, most often under antivirus/EDR file locking, cloud-sync filter drivers, or two concurrent Ceedling invocations racing the same destination. Deleting `build/` (or reinstalling the gem) and rebuilding works around it.
1. The Bullseye code coverage plugin has been temporarily disabled as of 1.0.0. The makers of Bullseye have generously provided a license for development, and the plugin will be available in 1.2.0.
1. Ceedling depends on the `erb` gem. Published `erb` versions include those affected by CVE-2026-41316, a flaw in how ERB reconstructs a template object from serialized data. Ceedling never reconstructs a template object this way, so Ceedling itself is not exposed. Dependency and security scanners may still flag the `erb` gem because the dependency is present. The `erb` dependency will be removed entirely as of 1.2.0 for multiple reasons beyond resolving the security issue.

---

## 1.0.0 — 2025-01-01

1. The new internal pipeline that allows builds to be parallelized and configured per-test-executable can mean a fair amount of duplication of steps. A header file may be mocked identically multiple times. The same source file may be compiled identically multiple times. The speed gains due to parallelization help make up for this. Future releases will concentrate on optimizing away duplication of build steps.
1. While header file search paths are now customizable per executable, this currently only applies to the search paths the compiler uses. Distinguishing test files or header files of the same name in different directories for test runner and mock generation respectively continues to rely on educated guesses in Ceedling code.
1. All header files needed for test compilation must be within the `:includes` path collection. Relative paths in include directives that extend outside the path collection will cause build problems.
1. C locales and non-ASCII characters (e.g. ©️ in a comment block) can cause parsing failures. 
1. System header includes `#include <system.h>` may not be properly distinguished from user includes `#include "user.h"` in many test preprocessing scenarios.
1. Any path for a C file specified with `TEST_SOURCE_FILE(...)` is in relation to **_project root_** — that is, from where you execute `ceedling` at the command line. If you move source files or change your directory structure, many of your `TEST_SOURCE_FILE(...)` calls may need to be updated. A more flexible and dynamic approach to path handling will come in a future update.
1. Ceedling’s many test preprocessing improvements are not presently able to preserve Unity’s special `TEST_CASE()` and `TEST_RANGE()` features. However, preprocessing of test files is much less frequently needed than preprocessing of mockable header files. Test preprocessing can now be configured to enable only one or the other. As such, these advanced Unity features can still be used in even sophisticated projects.
1. The Bullseye code coverage plugin has been temporarily disabled until a license can be procured that will allow updates and improvements.
