# Ceedling Plugin: Beep

Hear a useful beep at the end of a build.

# Plugin Overview

Are you getting too distracted surfing the internet, chatting with coworkers, or swordfighting while a long build runs? A friendly beep will let you know
it's time to pay attention again.

# Setup

To use this plugin, it must be enabled:

```yaml
:plugins:
  :enabled:
    - beep
```

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

## Adding arguments to a beep tool

Each of the sound options above map to a command line tool that Ceedling executes.

The `:beep`, `:speaker_test`, and `:say` tools can accept additional command line arguments to modify their behavior and sound ouput.

The `:speaker_test` tool is preconfigured with its `-t`, `-f`, and `-l` arguments to generate a 1 second 1000 Hz sine wave. Any additional arguments added through configuration will follow these (and could conflict).

To add additional arguments, a feature of Ceedling's project file handling allows you to merge a partial tool definition with tools already fully defined.

```yaml
:tools_beep_<sound option>: # Fill in <sound option> as from the list above
  :arguments:
    - ...                   # Add any aguments as a list of strings
```

## Example beep configurations in YAML

Enabling the plugin and event handlers with beep tool selections:

```yaml
:plugins:
  :enabled:
    - beep

# The following is the default configuration.
# It is shown for completeness, but it need not be duplicated in your project file 
# if the default settings work for you.
:beep:
  :on_done: :bell
  :on_error: :bell
```

Adding an argument to a beep tool:

```yaml
:plugins:
  :enabled:
    - beep

:beep:
  :on_done: :say # Choose the macOS `say` tool for build done events
                 # `:bell` remains the default for :on_error:

:tools_beep_say:
  :arguments:
    - -v daniel  # Change `say` command line to use Daniel voice

```

# Notes

* Some terminal emulators intercept and/or silence beeps. Remote terminal sessions can add further complication. Be sure to check relevant configuration options to accomplish what you want.

