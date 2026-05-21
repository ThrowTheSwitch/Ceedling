---
toc_depth: 2
---

# Developing Plugins for Ceedling

This guide walks you through the process of creating custom plugins for
[Ceedling](https://github.com/ThrowTheSwitch/Ceedling).

It is assumed that the reader has a working installation of Ceedling and some
basic usage experience, *i.e.* project creation/configuration and running tasks.

Some experience with Ruby and Rake will be helpful but not absolutely required.
You can learn the basics as you go — often by looking at other, existing 
Ceedling plugins or by simply searching for code examples online.

## Development Roadmap & Notes

(See Ceedling's _[release notes](https://github.com/ThrowTheSwitch/Ceedling/blob/master/docs/ReleaseNotes.md)_ for more.)

* Ceedling 1.0 marks the beginning of moving all of Ceedling away from relying
  on Rake. New, Rake-based plugins should not be developed. Rake dependencies
  among built-in plugins will be refactored as the transition occurs.
* Ceedling's entire plugin architecture will be overhauled in future releases.
  The current structure is too dependent on Rake and provides both too little
  and too much access to Ceedling's core.
* Certain aspects of Ceedling's plugin structure have developed organically.
  Consistency, coherence, and usability may not be high — particularly for 
  build step hook argument hashes and test results data structures used in 
  programmatic plugins.
* Because of iterating on Ceedling's core design and features, documentation
  here may not always be perfectly up to date.

---

## Custom Plugins Overview

Ceedling plugins extend Ceedling without modifying its core code. They are
implemented in YAML and the Ruby programming language and are loaded by 
Ceedling at runtime.

Plugins provide the ability to customize the behavior of Ceedling at various
stages of a build — preprocessing, compiling, linking, building, testing, and
reporting.

See the [`:plugins` configuration reference][plugins-config] for details of operation
and the [plugins overview][plugins-directory] for a directory of built-in plugins.

## Plugin Conventions & Architecture

Plugins are enabled and configured from within a Ceedling project's YAML
configuration file (`:plugins` section).

Conventions & requirements:

* Plugin configuration names, the containing directory names, and filenames 
  must:
   * All match (i.e. identical names)
   * Be snake_case (lowercase with connecting underscores).
* Plugins must be organized in a containing directory (the name of the plugin
  as used in the project configuration `:plugins` ↳ `:enabled` list is its 
  containing directory name).
* A plugin's containing directory must be located in a Ruby load path. Load
  paths may be added to a Ceedling project using the `:plugins` ↳ `:load_paths`
  list.
* Rake plugins place their Rakefiles in the root of the containing plugin 
  directory.
* Programmatic plugins must contain either or both `config/` and `lib/`
  subdirectories within their containing directories.
* Configuration plugins must place their files within a `config/` subdirectory
  within the plugin's containing directory.

Ceedling provides 3 options to customize its behavior through a plugin. Each
strategy is implemented with source files conforming to location and naming
conventions. These approaches can be combined.

1. Configuration (YAML & Ruby)
1. `Plugin` subclass (Ruby)
1. Rake tasks (Ruby)

[plugins-config]: ../../configuration/reference/plugins.md
[plugins-directory]: ../../plugins/index.md

<br/><br/>
