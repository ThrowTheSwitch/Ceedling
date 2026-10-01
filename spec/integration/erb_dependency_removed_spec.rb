# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Guards the removal of `erb` as a Ceedling dependency.
#
# Nothing declares erb any more, and that makes one pre-existing coupling
# dangerous. Thor declares no runtime dependencies at all, yet
# thor/actions/file_manipulation.rb requires erb at load time for a template
# action Ceedling never called. Ceedling stopped loading thor/actions when
# Actionator replaced it, so the tree is clean, but reintroducing that mixin
# would reintroduce an undeclared requirement. It would keep working on every
# Ruby that still ships erb as a default gem and fail only on the newest ones,
# which is the worst shape a regression can take.
#
# Two complementary checks. A static scan covers Ceedling's own code, where a
# reintroduced require would live. A real boot with erb made unloadable covers
# everything reached transitively, including Thor, which no scan of this repo
# could ever see.
#
# Checking $LOADED_FEATURES in process would be the obvious approach and does not
# work: rspec/core itself requires erb, so erb is always loaded inside any RSpec
# process regardless of what Ceedling does. Hence the subprocess.
#
# Integration tier because both checks read the real tree and one shells out.

require 'spec_helper'
require 'spec_integration_helper'
require 'open3'

describe 'erb dependency removal (integration)' do
  include IntegrationSpecHelpers

  CEEDLING_ROOT = File.expand_path( '../..', __dir__ )

  # Ruby source that makes `require 'erb'` fail the way it would on a Ruby that
  # ships no erb and no gem supplying one.
  ERB_BLOCKING_SHIM = <<~'RUBY'
    module Kernel
      alias_method :__erb_guard_require, :require
      def require(name)
        if name.to_s == 'erb' || name.to_s.start_with?('erb/')
          raise LoadError, "erb was required, but Ceedling no longer depends on it"
        end
        __erb_guard_require(name)
      end
    end
  RUBY

  describe 'Ceedling source' do
    # Comments are stripped before matching so the several comments explaining why
    # ERB was removed do not read as usages. The historical assets/template.erb
    # filename survives as a compatibility path and is lower case, so neither
    # pattern here matches it.
    def erb_usages_under(glob)
      Dir.glob( File.join( CEEDLING_ROOT, glob ) ).reject { |p| p.include?( '/vendor/' ) }.flat_map do |path|
        next [] if File.directory?( path )

        # UTF-8 named explicitly rather than left to the platform default. Ceedling
        # sources carry characters like ↳ and ➡️, and a default of US-ASCII makes
        # every line operation below raise on them.
        File.readlines( path, encoding: Encoding::UTF_8 ).each_with_index.filter_map do |line, index|
          code = line.sub( /#.*/, '' )
          next unless code.match?( /require\s+['"]erb['"]/ ) || code.match?( /\bERB\b/ )

          "#{path.sub( CEEDLING_ROOT + '/', '' )}:#{index + 1}: #{line.strip}"
        end
      end
    end

    it 'never requires erb or references ERB' do
      usages = erb_usages_under( 'lib/**/*.rb' ) +
               erb_usages_under( 'bin/*' ) +
               erb_usages_under( 'plugins/**/*.rb' )

      expect(usages).to be_empty, "erb reintroduced into Ceedling source:\n#{usages.join("\n")}"
    end
  end

  describe 'a real Ceedling boot' do
    # `version` loads bin/cli.rb and builds the whole bin-tier object graph, which
    # is where a reintroduced Thor::Actions mixin would pull erb back in.
    it 'succeeds with erb made unloadable' do
      with_source_tree({}) do |dir|
        shim = File.join( dir, 'erb_blocking_shim.rb' )
        File.write( shim, ERB_BLOCKING_SHIM )

        stdout, stderr, status = Open3.capture3(
          RbConfig.ruby,
          "-r#{shim}",
          "-I#{File.join( CEEDLING_ROOT, 'bin' )}",
          "-I#{File.join( CEEDLING_ROOT, 'lib' )}",
          File.join( CEEDLING_ROOT, 'bin', 'ceedling' ),
          'version',
          chdir: dir
        )

        expect(status.exitstatus).to eq( 0 ),
          "Ceedling failed to boot without erb.\nstdout:\n#{stdout}\nstderr:\n#{stderr}"
      end
    end

    # Proves the shim actually blocks erb rather than silently doing nothing, so a
    # pass above means something.
    it 'has a shim that genuinely blocks erb' do
      with_source_tree({}) do |dir|
        shim = File.join( dir, 'erb_blocking_shim.rb' )
        File.write( shim, ERB_BLOCKING_SHIM )

        _stdout, stderr, status = Open3.capture3(
          RbConfig.ruby, "-r#{shim}", '-e', 'require "erb"'
        )

        expect(status.exitstatus).to_not eq( 0 )
        expect(stderr).to match( /no longer depends on it/ )
      end
    end
  end
end
