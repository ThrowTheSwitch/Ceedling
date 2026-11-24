# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rbconfig'
require 'tmpdir'

# The contract harness: rows that state what Ceedling does with a tree and its
# configuration, and what the compiler does with the same tree.
#
# Everything it touches is found from this checkout, so the tier runs from an installed
# gem as it does from a clone. See spec/contract/README.md.
module Contract

  # The checkout this harness belongs to, whose bin/ceedling builds every row
  CHECKOUT = File.expand_path( File.join( __dir__, '..', '..', '..' ) ).freeze

  ROWS_DIR     = File.join( CHECKOUT, 'spec', 'contract', 'rows' ).freeze
  RECORDED_DIR = File.join( CHECKOUT, 'spec', 'contract', 'recorded' ).freeze
  PROBE_FILE   = File.join( __dir__, 'probe', 'contract_probe.rb' ).freeze

  PLATFORMS = %w[linux macos windows].freeze
  MODES     = %w[none mocks tests all].freeze

  # Raised for a row file the loader cannot accept
  class RowError < StandardError; end

  # Raised when the oracle's own answer breaks a rule the compiler always keeps
  class OracleError < StandardError; end

  # Raised when a live report disagrees with what is recorded or declared
  class Mismatch < StandardError; end

  # The platform this process runs on, as rows name it
  def self.platform
    case RbConfig::CONFIG['host_os']
    when /mswin|mingw|cygwin/ then 'windows'
    when /darwin/             then 'macos'
    else 'linux'
    end
  end

  def self.windows?
    return platform == 'windows'
  end

  # The compiler the oracle runs, `gcc` unless CONTRACT_CC names another
  def self.cc
    value = ENV['CONTRACT_CC'].to_s.strip
    return value.empty? ? 'gcc' : value
  end

  # Where observed reports go on a mismatch or while recording
  def self.out_dir
    value = ENV['CONTRACT_OUT'].to_s.strip
    return value.empty? ? File.join( Dir.tmpdir, 'ceedling-contract' ) : File.expand_path( value )
  end

  def self.recording?
    return ENV['CONTRACT_RECORD'] == '1'
  end

  # Whether an executable is on the PATH
  def self.tool?(name)
    exts = windows? ? ENV.fetch( 'PATHEXT', '.EXE;.BAT;.CMD' ).split( ';' ) + [''] : ['']
    return ENV.fetch( 'PATH', '' ).split( File::PATH_SEPARATOR ).any? do |dir|
      exts.any? { |ext| File.executable?( File.join( dir, "#{name}#{ext}" ) ) && !File.directory?( File.join( dir, "#{name}#{ext}" ) ) }
    end
  end

end
