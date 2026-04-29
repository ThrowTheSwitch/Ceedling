# `:plugins` Ceedling extensions

See the section below dedicated to plugins for more information. This section
pertains to enabling plugins in your project configuration.

Ceedling includes a number of built-in plugins. See the collection within the
project at [plugins/][ceedling-plugins] or the
[plugins documentation][ceedling-plugins]. Each built-in plugin subdirectory
includes thorough documentation covering its capabilities and configuration
options.

_Note_: Many users find that the handy-dandy [Command Hooks plugin][command-hooks]
is often enough to meet their needs. This plugin allows you to connect your own
scripts and command line tools to Ceedling build steps.

For documentation on creating your own custom plugins, see the
[Plugin Development Guide][custom-plugins].

## `:load_paths`

Base paths to search for plugin subdirectories or extra Ruby functionality.

Ceedling maintains the Ruby load path for its built-in plugins. This list of
paths allows you to add your own directories for custom plugins or simpler
Ruby files referenced by your Ceedling configuration options elsewhere.

**Default**: `[]` (empty)

## `:enabled`

List of plugins to be used — a plugin's name is identical to the subdirectory
that contains it.

**Default**: `[]` (empty)

Plugins can provide a variety of added functionality to Ceedling. In general
use, it's assumed that at least one reporting plugin will be used to format
test results (usually `report_tests_pretty_stdout`).

If no reporting plugins are specified, Ceedling will print to `$stdout` the
(quite readable) raw test results from all test fixtures executed.

## Example `:plugins` YAML blurb

```yaml
:plugins:
  :load_paths:
    - project/tools/ceedling/plugins  # Home to your collection of plugin directories.
    - project/support                 # Home to some ruby code your custom plugins share.
  :enabled:
    - report_tests_pretty_stdout      # Nice test results at your command line.
    - our_custom_code_metrics_report  # You created a plugin to scan all code to collect 
                                      # line counts and complexity metrics. Its name is a
                                      # subdirectory beneath the first `:load_path` entry.

```

[custom-plugins]: ../../development/plugins/index.md
[ceedling-plugins]: ../../plugins/index.md
[command-hooks]: ../../plugins/command-hooks.md
