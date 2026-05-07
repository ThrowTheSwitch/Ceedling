# Ceedling's Environment Variables

Ceedling recognizes several environment variables that control its behavior independently of your project configuration file.

## Project configuration filepath

The environment variable `CEEDLING_PROJECT_FILE` is [one option](../configuration/loading.md)
to point Ceedling at your project configuration file.

## Logging decorators

Ceedling attempts to bring more joy to your console logging. This may include
fancy Unicode characters, emoji, or color.

Example:
```
-----------------------
❌ OVERALL TEST SUMMARY
-----------------------
TESTED:  6
PASSED:  5
FAILED:  1
IGNORED: 0
```

By default, Ceedling makes an educated guess as to which platforms can best
support this. Some platforms (we're looking at you, Windows) do not typically
have default font support in their terminals for these features. So, by default
this feature is disabled on problematic platforms while enabled on others.

!!! warning "`CEEDLING_DECORATORS` cannot be set with `:environment`"
    Ceedling’s logger must load before any environment variables are processed 
    in your project configuration. As such, `CEEDLING_DECORATORS` can only be set 
    in your environment before Ceedling runs.

An environment variable `CEEDLING_DECORATORS` forces decorators on or off with a
`true` (`1`) or `false` (`0`) string value.

If you find a monospaced font that provides emojis, etc. and works with Windows'
command prompt, you can (1) Install the font (2) change your command prompt's
font (3) set `CEEDLING_DECORATORS` to `true`.

## Mixins

[Mixins][mixins-config-section] allow you to merge configuration with your project 
configuration just after the base project file is loaded.

Mixins can be specified from the command line, in your project configuration file
and via environment variables.

Environment variables named `CEEDLING_MIXIN_#` — where `#` is any positive 
integer — specify filepaths to mixin YAML files to be merged into your base 
project configuration. Multiple mixin environment variables are merged in 
ascending numeric order (e.g. `CEEDLING_MIXIN_1` before `CEEDLING_MIXIN_5` 
before `CEEDLING_MIXIN_99`).

See [_Loading Configuration_](../configuration/loading.md#mixin-environment-variables)
for the full details on Mixin environment variables.

[mixins-config-section]: ../configuration/loading.md#applying-mixins-to-base-configuration

<br/><br/>
