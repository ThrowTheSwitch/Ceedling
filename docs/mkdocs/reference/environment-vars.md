# Environment Variables Reference

See [Getting Started → Environment Variables](../configuration/environment-vars.md)
for context on when and why to use these variables.

## Project configuration

### `CEEDLING_PROJECT_FILE`

Points Ceedling at your project configuration file. This is
[one of several options](../configuration/loading.md) for specifying the
project file location.

### `CEEDLING_MIXIN_#`

Environment variables named `CEEDLING_MIXIN_#` — where `#` is any positive
integer — specify filepaths to mixin YAML files to be merged into your base
project configuration. Multiple mixin environment variables are merged in
ascending numeric order (e.g. `CEEDLING_MIXIN_1` before `CEEDLING_MIXIN_5`
before `CEEDLING_MIXIN_99`).

See [_Loading Configuration_](../configuration/mixins.md#environment-variables)
for the full details on Mixin environment variables.

## Console output — `CEEDLING_DECORATORS`

Forces Ceedling's console logging decorators (fancy Unicode characters, emoji,
and color) on or off.

!!! warning "`CEEDLING_DECORATORS` cannot be set with `:environment`"
    Ceedling's logger must load before any environment variables are processed 
    in your project configuration. As such, `CEEDLING_DECORATORS` can only be set 
    in your environment before Ceedling runs.

By default, Ceedling makes an educated guess as to which platforms can best
support decorators. Some platforms (we're looking at you, Windows) do not
typically have default font support in their terminals for these features. So,
by default this feature is disabled on problematic platforms while enabled on
others.

Set `CEEDLING_DECORATORS` to `true` (`1`) to force decorators on, or `false`
(`0`) to force them off.

Example with decorators enabled:

```
-----------------------
❌ OVERALL TEST SUMMARY
-----------------------
TESTED:  6
PASSED:  5
FAILED:  1
IGNORED: 0
```

If you find a monospaced font that provides emojis, etc. and works with Windows'
command prompt, you can (1) Install the font (2) change your command prompt's
font (3) set `CEEDLING_DECORATORS` to `true`.

<br/><br/>
