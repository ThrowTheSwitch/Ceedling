# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'yaml'

class YamlWrapper

  # Ceedling loads YAML from project config files, cache files, and generated test-result
  # files. `YAML.load` can instantiate arbitrary Ruby objects from that content, which is
  # unnecessary and unsafe -- `YAML.safe_load` restricts deserialization to plain data types
  # plus whatever is explicitly permitted below.
  #
  # Ceedling's YAML convention (see assets/project.yml, cacheinator.rb, generator_test_results.rb)
  # uses colon-prefixed keys (`:foo:`) to mean "this key is a Ruby Symbol"; unprefixed keys
  # stay Strings. Psych recognizes `:foo` scalar notation as Symbol by default -- safe_load
  # just needs `Symbol` added to its class allowlist to permit it. Aliases (`&anchor`/`*alias`)
  # are off by default in safe_load as a DoS guard, so they're explicitly re-enabled.

  # safe_load's calling convention changed between Psych 3 (bundled with Ruby 3.0) and
  # Psych 4+ (bundled with Ruby 3.1+, and installable on any Ruby >= 3.0):
  #   Psych 4+:  safe_load(yaml, permitted_classes: [], aliases: false, ...)   # keyword args
  #   Psych 3:   safe_load(yaml, permitted_classes = [], permitted_symbols = [], aliases = false)  # positional
  # Psych::VERSION is fixed for the life of the process, and #load/#load_string are called
  # repeatedly over a Ceedling run, so the version check is memoized rather than repeated
  # per call.

  def self.psych_safe_load_uses_keywords?
    return @psych_safe_load_uses_keywords if defined?(@psych_safe_load_uses_keywords)
    @psych_safe_load_uses_keywords = (Gem::Version.new(Psych::VERSION) >= Gem::Version.new("4.0"))
  end

  def load(filepath)
    load_string( File.read(filepath) )
  end

  def load_string(source)
    if self.class.psych_safe_load_uses_keywords?
      YAML.safe_load(source, permitted_classes: [Symbol], aliases: true)
    else
      YAML.safe_load(source, [Symbol], [], true)
    end
  end

  def dump(filepath, structure)
    File.open(filepath, 'w') do |output|
      YAML.dump(structure, output)
    end
  end

end
