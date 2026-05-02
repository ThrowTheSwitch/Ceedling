# Subprojects

The `subprojects` plugin supports subproject release builds of static libraries.
It manages differing sets of compiler flags and linker flags that fit the needs
of different library builds.

## Overview

This plugin enables Ceedling to manage complex release builds that involve
multiple separate library subprojects — each potentially with its own build
settings, compiler flags, and linker flags — as dependencies of a top-level
release artifact.

## Setup

Enable the plugin in your Ceedling project file by adding `subprojects` to the
list of enabled plugins.

```yaml
:plugins:
  :enabled:
    - subprojects
```

## Documentation

See the [Plugin Development Guide](../development/plugins/index.md) for context on
how Ceedling plugins work.

For full details on configuring the `subprojects` plugin, see the plugin's
source and any inline documentation in the plugin directory.

_Note:_ This plugin is especially useful for sophisticated release builds that
are beyond the scope of Ceedling's standard release build configuration. If your
project requires building multiple libraries with different toolchain settings,
`subprojects` is the recommended approach.

<br/><br/>
