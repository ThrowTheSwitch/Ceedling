---
toc_depth: 3
---

# Plugin Option 1: Configuration

The configuration option, surprisingly enough, provides Ceedling configuration
values. Configuration plugin values can supplement or override project
configuration values.

Not long after Ceedling plugins were developed the `option:` feature was added
to Ceedling to merge in secondary configuration files. This feature is
typically a better way to manage multiple configurations and in many ways
supersedes a configuration plugin.

That said, a configuration plugin is more capable than the `option:` feature and
can be appropriate in some circumstances. Further, Ceedling's configuration
plugin abilities are often a great way to provide configuration to
programmatic `Plugin` subclasses (Ceedling plugins options #2).

## Three flavors of configuration plugins exist

1. **YAML defaults.** The data of a simple YAML file is incorporated into
   Ceedling's configuration defaults during startup.
1. **Programmatic (Ruby) defaults.** Ruby code creates a configuration hash 
   that Ceedling incorporates into its configuration defaults during startup. 
   This provides the greatest flexibility in creating configuration values.
1. **YAML configurations.** The data of a simple YAML file is incorporated into
   Ceedling's configuration much like your project configuration file.

## Example configuration plugin layout

Project configuration file:

```yaml
:plugins:
  :load_paths:
    - support/plugins
  :enabled:
    - zoom_zap
```

Ceedling project directory structure:

(Third flavor of configuration plugin shown.)

```
project/
├── project.yml
└── support/
    └── plugins/
        └── zoom_zap/
            └── config/
                └── zoom_zap.yml
```

## Ceedling configuration build & use

Configuration is developed at startup by assembling defaults, collecting 
user-configured settings, and then populating any missing values with defaults.

Defaults:

1. Ceedling loads its own defaults separately from your project configuration
1. Supporting framework defaults such as for CMock are populated into (1)
1. Any plugin defaults are merged with (2).

Final project configuration:

1. Your project file is loaded and any mixins merged
1. Supporting framework settings that depend on project configuration are populated
1. Plugin configurations are merged with the result of (1) and (2)
1. Defaults are populated into your project configuration
1. Path standardization, string replacement, and related occur throughout the final 
   configuration

Merging means that existing simple configuration values are replaced or, in the 
case of containers such as lists and hashes, values are added to. If no such 
key/value pairs already exist, they are simply inserted into the configuration. 

Populating means inserting a configuration value if none already exists. As an 
example, if Ceedling finds no compiler defined for test builds in your project
configuration, it populates your configuration with its own internal tool definition.

A plugin may implement its own code to extract custom configuration from
the Ceedling project file. See the built-in plugins for examples. For instance, the
[Beep plugin](../../plugins/beep.md) makes use of a top-level `:beep` section in project 
configuration. In such cases, it's typically wise to make use of a plugin's option for 
defining default values. Configuration handling code is greatly simplified if values are 
guaranteed to exist in some form. This eliminates a great deal of presence checking
and related code.

## Configuration Plugin Flavors

### Configuration Plugin Flavor A: YAML Defaults

Naming and location convention: `<plugin_name>/config/defaults.yml`

Configuration values are defined inside a YAML file just as the Ceedling project
configuration file.

Keys and values are defined in Ceedling's "base" configuration along with all
default values Ceedling loads at startup. If a particular key/value pair is
already set at the time the plugin attempts to set it, it will not be
redefined.

YAML values are static apart from Ceedling's ability to perform string
substitution at configuration load time (see the [configuration reference][string-expansion] for more).
Programmatic Ruby defaults (next section) are more flexible but more
complicated.

```yaml
# Any valid YAML is appropriate
:key:
  :value: <setting>
```

### Configuration Plugin Flavor B: Programmatic (Ruby) Defaults

Naming and location convention: `<plugin_name>/config/defaults_<plugin_name>.rb`

Configuration values are defined in a Ruby hash returned by a "naked" function
`get_default_config()` in a Ruby file. The Ruby file is loaded and evaluated at
Ceedling startup. It can contain anything allowed in a Ruby script file but
must contain the accessor function. The returned hash's top-level keys will
live in Ceedling's configuration at the same level in the configuration
hierarchy as a Ceedling project file's top-level keys ('top-level' refers to
the left-most keys in the YAML, not to how "high" the keys are towards the top
of the file).

Keys and values are defined in Ceedling's "base" configuration along with all
default values Ceedling loads at startup. If a particular key/value pair is
already set at the time the plugin attempts to set it, it will not be
redefined.

This configuration option is more flexible than that documented in the previous
section as full Ruby execution is possible in creating the defaults hash.

### Configuration Plugin Flavor C: YAML Values

Naming and location convention: `<plugin_name>/config/<plugin_name>.yml`

Configuration values are defined inside a YAML file just as the Ceedling project
configuration file.

Keys and values are defined in Ceedling's "base" configuration along with all
default values Ceedling loads at startup. If a particular key/value pair is
already set at the time the plugin attempts to set it, it will not be
redefined.

YAML values are static apart from Ceedling's ability to perform string
substitution at configuration load time (see the [configuration reference][string-expansion] for more).
Programmatic Ruby defaults (next section) are more flexible but more
complicated.

```yaml
# Any valid YAML is appropriate
:key:
  :value: <setting>
```

[string-expansion]: ../../configuration/project-file.md#inline-ruby-string-expansion
