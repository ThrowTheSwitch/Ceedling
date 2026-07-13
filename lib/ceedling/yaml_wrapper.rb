# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'yaml'
require 'ceedling/exceptions'

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
    begin
      source = File.read(filepath)
    rescue Errno::ENOENT
      raise YamlLoadException.new(
        reason: :not_found, source: filepath, original_error: nil,
        message: "Could not find YAML file ⏩️ #{filepath}"
      )
    end

    load_string(source, source_label: filepath)
  end

  def load_string(source, source_label: '<inline YAML>')
    if self.class.psych_safe_load_uses_keywords?
      YAML.safe_load(source, permitted_classes: [Symbol], aliases: true, filename: source_label)
    else
      YAML.safe_load(source, [Symbol], [], true, source_label)
    end

  # The YAML parsed fine syntactically, but it contains a tag/type (e.g. `!ruby/object:...`)
  # that isn't on safe_load's permitted-class allowlist. This is Psych doing its safety job,
  # not a content typo -- surfaced separately from :syntax so the user understands the fix is
  # "remove this Ruby-object tag," not "fix a formatting mistake."
  rescue Psych::DisallowedClass => e
    raise YamlLoadException.new(
      reason: :unsafe, source: source_label, original_error: e,
      message: "YAML content in #{source_label} uses a Ruby type not permitted by safe YAML loading ⏩️ #{e.message}"
    )

  # Catches every other Psych::Exception subclass (Psych::SyntaxError, Psych::BadAlias,
  # Psych::AnchorNotDefined, etc.) -- i.e. the YAML text itself is malformed: bad syntax,
  # a dangling alias reference, and similar authoring mistakes the user needs to fix in
  # the YAML source. Ordered after Psych::DisallowedClass, which is a subclass of
  # Psych::Exception and needs its own more specific message.
  rescue Psych::Exception => e
    raise YamlLoadException.new(
      reason: :syntax, source: source_label, original_error: e,
      message: "Malformed YAML content in #{source_label} ⏩️ #{e.message}"
    )

  # Not a problem with the YAML content at all -- the installed Psych version rejected one
  # of the arguments safe_load was called with. self.class.psych_safe_load_uses_keywords?
  # already picks the right calling convention for the installed Psych, so this should be
  # unreachable in practice; it exists as a last-resort safety net for an unanticipated
  # Psych version/interface mismatch, reported distinctly so it isn't mistaken for a user
  # YAML-authoring error.
  rescue ArgumentError => e
    raise YamlLoadException.new(
      reason: :incompatible, source: source_label, original_error: e,
      message: "Installed Psych YAML library (#{Psych::VERSION}) does not support a safe-loading feature Ceedling requires ⏩️ #{e.message}"
    )
  end

  def dump(filepath, structure)
    File.open(filepath, 'w') do |output|
      YAML.dump(structure, output)
    end
  end

end
