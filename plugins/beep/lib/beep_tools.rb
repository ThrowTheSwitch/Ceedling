BEEP_TOOLS = {

  # Most generic beep option across all platforms -- echo the ASCII bell character
  :bell => {
    :executable => 'echo'.freeze,                     # Using `echo` shell command / command line application
    :name => 'default_beep_bell'.freeze,
    :arguments => [
      *('-n'.freeze unless SystemWrapper.windows?),   # No trailing newline for Unix-style echo (argument omitted on Windows)
      "\x07".freeze                                   # Unprintable ASCII bell character, escaped in Ruby string
    ].freeze
  }.freeze,

  # Terminal put the bell character on Unix-derived platforms
  :tput => {
    :executable => 'tput'.freeze,                     # `tput` command line application
    :name => 'default_beep_tput'.freeze,
    :arguments => [
      "bel".freeze                                    # `tput` argument for bell character (named 'bel' in ASCII standard)
    ].freeze
  }.freeze,

  # Old but widely available `beep` tone generator package for Unix-derived platforms (not macOS) 
  :beep => {
    :executable => 'beep'.freeze,                     # `beep` command line application
    :name => 'default_beep_beep'.freeze,
    :arguments => [].freeze                           # Default beep (no arguments)
  }.freeze,
  
  # Widely available tone generator package for Unix-derived platforms (not macOS)
  :speaker_test => {
    :executable => 'speaker-test'.freeze,             # `speaker-test` command line application
    :name => 'default_beep_speaker_test'.freeze,
    :arguments => [                                   # 1000 hz sine wave frequency
      '-t sine'.freeze,
      '-f 1000'.freeze,
      '-l 1'.freeze
    ].freeze
  }.freeze,

  # macOS text to speech
  :say => {
    :executable => 'say'.freeze,                      # macOS `say` command line application
    :name => 'default_beep_say'.freeze,
    :arguments => [
      "\"${1}\""                                      # Replacement argument for text
    ].freeze
  }.freeze,

}.freeze
