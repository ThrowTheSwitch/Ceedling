BEEP_TOOLS = {
  :bell => {
    :executable => 'echo'.freeze,
    :name => 'default_beep_bell'.freeze,
    :stderr_redirect => StdErrRedirect::NONE.freeze,
      :optional => false.freeze,
    :arguments => [
      *('-ne'.freeze unless SystemWrapper.windows?),
      "\x07".freeze
    ].freeze
  }.freeze,
  :speaker_test => {
    :executable => 'speaker-test'.freeze,
    :name => 'default_beep_speaker_test'.freeze,
    :stderr_redirect => StdErrRedirect::NONE.freeze,
      :optional => false.freeze,
    :arguments => [
      - '-t sine'.freeze,
      - '-f 1000'.freeze,
      - '-l 1'.freeze
    ].freeze
  }.freeze
}.freeze
