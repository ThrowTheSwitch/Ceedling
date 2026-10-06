# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rubygems'

# The sole I/O boundary for SBOM generation.
#
# Every filesystem read and shell-out lives here, and nothing else in tools/sbom
# touches `File`, `Dir`, or a subprocess. Each method performs one read and hands back
# raw content, which is what lets the parsers, the inventory, and both serializers be
# specified without a filesystem. This file carries no logic worth testing and has no
# specs of its own by design.
#
# Reads raise rather than returning empty on failure. A silently empty SBOM is worse
# than no SBOM, since it reports an absence of components rather than an absence of
# knowledge.
module Sbom
  class Sources

    class Error < RuntimeError; end

    def initialize(root)
      @root = root
    end

    # Declared runtime dependencies and the gem version come from the gemspec itself
    # rather than from parsing it, so the declaration Ceedling publishes is the one
    # the document reports.
    def gemspec
      Gem::Specification.load( path( 'ceedling.gemspec' ) ) or
        raise Error, 'ceedling.gemspec could not be loaded'
    end

    def lockfile_content
      read( 'Gemfile.lock' )
    end

    # `--recursive` reaches the pair of gitlinks inside CMock, which a plain
    # `git ls-tree` cannot see.
    def submodule_status
      capture( 'git submodule status --recursive' )
    end

    # Header-derived versions for Unity, CMock, and CException, by way of the existing
    # Versionator, which is already the authority on them elsewhere in Ceedling. It
    # requires `bin`, `lib`, and `lib/ceedling` on the load path: `exceptions` and
    # `constants` resolve under lib/ceedling while `version` sits directly in lib.
    #
    # Versionator raises when a header cannot be read, which is the behavior wanted
    # here. An uninitialized submodule should stop generation rather than yield a
    # document missing versions.
    def header_versions
      load_versionator

      versionator = Versionator.new( @root, path( 'vendor' ) )

      {
        ceedling: versionator.ceedling_tag,
        unity: versionator.unity_tag,
        cmock: versionator.cmock_tag,
        cexception: versionator.cexception_tag
      }
    end

    # DIY carries its version in source rather than in a header macro, having been a
    # gem before Ceedling vendored it.
    def diy_version
      read( File.join( 'vendor', 'diy', 'lib', 'diy.rb' ) )[/VERSION\s*=\s*['"]([^'"]+)['"]/, 1]
    end

    # Capitalization of license filenames is inconsistent across the vendored projects
    # -- `license.txt`, `LICENSE.txt`, and fff's extensionless `LICENSE` all appear --
    # so match a case-insensitive pattern against directory entries.
    #
    # Matching happens in Ruby rather than through a glob flag. `File::FNM_CASEFOLD`
    # has no effect in `Dir.glob`, which silently returns nothing for `LICENSE.txt`
    # against a lowercase pattern.
    LICENSE_NAME = /\Alicen[sc]e/i

    def license_text(relative_dir)
      directory = path( relative_dir )
      return nil unless File.directory?( directory )

      name = Dir.children( directory ).grep( LICENSE_NAME ).sort.first
      return nil if name.nil?

      File.read( File.join( directory, name ), encoding: 'UTF-8' )
    end

    def exist?(relative_path)
      File.exist?( path( relative_path ) )
    end

    private

    def path(relative)
      File.join( @root, relative )
    end

    def read(relative)
      File.read( path( relative ), encoding: 'UTF-8' )
    rescue SystemCallError => e
      raise Error, "could not read #{relative}: #{e.message}"
    end

    def capture(command)
      output = Dir.chdir( @root ) { `#{command}` }
      raise Error, "`#{command}` failed" unless $?.success?

      output
    end

    def load_versionator
      return if defined?( Versionator )

      %w[bin lib lib/ceedling].each { |dir| $LOAD_PATH.unshift( path( dir ) ) }
      require 'versionator'
    end

  end
end
