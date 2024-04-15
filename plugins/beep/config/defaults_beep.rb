# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Most generic beep option across all platforms -- echo the ASCII bell character
DEFAULT_BEEP_BELL_TOOL = {
  :executable => 'echo'.freeze,                     # Using `echo` shell command / command line application
  :optional => true.freeze,
  :name => 'default_beep_bell'.freeze,
  :arguments => [
    *('-n'.freeze unless SystemWrapper.windows?),   # No trailing newline for Unix-style echo (argument omitted on Windows)
    "\x07".freeze                                   # Unprintable ASCII bell character, escaped in Ruby string
    ].freeze
  }

# Terminal put the bell character on Unix-derived platforms
DEFAULT_BEEP_TPUT_TOOL = {
  :executable => 'tput'.freeze,                     # `tput` command line application
  :optional => true.freeze,
  :name => 'default_beep_tput'.freeze,
  :arguments => [
    "bel".freeze                                    # `tput` argument for bell character (named 'bel' in ASCII standard)
    ].freeze
  }

# Old but widely available `beep` tone generator package for Unix-derived platforms (not macOS) 
DEFAULT_BEEP_BEEP_TOOL = {
  :executable => 'beep'.freeze,                     # `beep` command line application
  :optional => true.freeze,
  :name => 'default_beep_beep'.freeze,
  :arguments => [].freeze                           # Default beep (no arguments)
  }
  
# Widely available tone generator package for Unix-derived platforms (not macOS)
DEFAULT_BEEP_SPEAKER_TEST_TOOL = {
  :executable => 'speaker-test'.freeze,             # `speaker-test` command line application
  :optional => true.freeze,
  :name => 'default_beep_speaker_test'.freeze,
  :arguments => [                                   # 1000 hz sine wave frequency
    '-t sine'.freeze,
    '-f 1000'.freeze,
    '-l 1'.freeze
    ].freeze
  }

# macOS text-to-speech tool
DEFAULT_BEEP_SAY_TOOL = {
  :executable => 'say'.freeze,                      # macOS `say` command line application
  :optional => true.freeze,
  :name => 'default_beep_say'.freeze,
  :arguments => [
    "\"${1}\""                                      # Replacement argument for text
    ].freeze
  }

def get_default_config
  return :tools => {
    :beep_bell => DEFAULT_BEEP_BELL_TOOL,
    :beep_tput => DEFAULT_BEEP_TPUT_TOOL,
    :beep_beep => DEFAULT_BEEP_BEEP_TOOL,
    :beep_speaker_test => DEFAULT_BEEP_SPEAKER_TEST_TOOL,
    :beep_say => DEFAULT_BEEP_SAY_TOOL
  }
end