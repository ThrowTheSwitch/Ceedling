# Ceedling Plugin: Beep

# Plugin Overview

This plugin simply beeps at the end of a build.

Are you getting too distracted surfing the internet, chatting with coworkers, or swordfighting while a long build runs? A friendly beep will let you know
it's time to pay attention again.

# Configuration

Beep includes a default configuration. By just enabling the plugin, the simplest cross-platform sound mechanism (`:bell` below) is automatically enabled for both
build completion and build error events.

If you would like to customize your beeps, the following explains your options.

## Events

When this plugin is enabled, a beep is sounded when:

* A test build or release build finish successfully.
* An error condition breaks a build.

To change the default sound for each event, define `:on_done` and `:on_error` beneath a top-level `:beep` entry in your configuration file. See example below.

## Sound options

The following options are fixed. At present, this plugin does not expose customization settings.

* `:bell`

  `:bell` is the simplest and most widely available option for beeping. This option simply `echo`s the unprintable [ASCII bell character][ascii-bel-character] to a command terminal. This option is generally available on all platforms, including Windows.

  [ascii-bel-character]: https://en.wikipedia.org/wiki/Bell_character

* `:tput`

  [`tput`][tput] is a command line utility widely availble among Unix derivatives, including Linux and macOS. The `tput` utility uses the terminfo database to make the values of terminal-dependent capabilities (including the [ASCII bell character][ascii-bel-character]) and terminal information available to the shell.

  If the `echo`-based method used by the `:bell` option is not successful, `:tput` is a good backup option (except on Windows).

  [tput]: https://linux.die.net/man/1/tput

* `:beep`

  [`beep`][beep] is an old but widely available Linux package for tone generation using the PC speaker.

  `beep` requires isntallation and the possibility of a complementary kernel module.

  The original audio device in a PC before sound cards was a simple and limited speaker directly wired to a motherboard. Rarely, modern systems still have this device. More commonly, its functions are routed to a default mode of modern audio hardware. `beep` may not work on modern Linux systems. If it is a viable option, this utility is typically dependent on a PC speaker kernel module and related configuration.

  [beep]: https://linux.die.net/man/1/beep

* `:speaker_test`

  [`speaker-test`][speaker-test] is a Linux package commonly available for tone generation using a system's audio features.

  `speaker-test` requires installation as well as audio subsystem configuration.

  _Note:_ `speaker-test` typically mandates a 4 second minimum run, even if the configured sound plays for less than this minimum. Options to limit `speaker-test`'s minimum time are likely possible but would require combining advanced Ceedling features.

  [speaker-test]: https://linux.die.net/man/1/speaker-test

* `:say`

  macOS includes a built-in text-to-speech command line application, [`say`][say]. When Ceedling is running on macOS and this beep option is selected, Ceedling events will be verbally announced.

  [say]: https://ss64.com/mac/say.html

## Example beep configurations in YAML

In fact, this is the default configuration (and need not be duplicated in your project file).

```yaml
:beep:
  :on_done: :bell
  :on_error: :bell
```

# Notes

* Some terminal emulators intercept and/or silence beeps. Remote terminal sessions can add further complication. Be sure to check relevant configuration options to accomplish what you want.

