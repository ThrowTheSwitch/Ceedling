# Ceedling Plugin: Ccache 

This plugin allows you to easily cache compilation runs using [ccache](https://ccache.dev/).

From the ccache docs:

> Ccache is a compiler cache. It speeds up recompilation by caching the result of previous compilations and detecting when the same compilation is being done again.

# Requirements

This plugin requires that ccache is installed on the machine and available in your path

# Configuration

A full descriptions of all configuration options can be found in the [ccache manual](https://ccache.dev/manual/4.10.2.html#_configuration_options)

When configuring, the options can either be set in a ccache configuration file, as environment variables or in your ceedling configuration file.

```yml
:ccache:
  :cache_dir: cache # Relative to the build root, unless an absolute path is specified
  :compiler_check: content 
  :compression: FALSE 
```

If nothing is set, the cache folder will be placed in the ceedling build folder and all other options will use the ccache defaults.