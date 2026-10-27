# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'exceptions'
require 'constants'  # Filename constants
require 'ceedling/installation'

## Definitions
##  TAG: <#.#.#> version string used to package the software bundle
##  BUILD: TAG combined with git commit hash (<#.#.#>-<SHA>)

class Versionator

  # Vendored framework headers and the prefix of their version macros
  FRAMEWORK_HEADERS = {
    'UNITY'      => File.join( 'unity', 'src', 'unity.h' ),
    'CMOCK'      => File.join( 'cmock', 'src', 'cmock.h' ),
    'CEXCEPTION' => File.join( 'c_exception', 'lib', 'CException.h' )
  }.freeze

  attr_reader :ceedling_tag, :ceedling_build, :ceedling_install_path
  attr_reader :unity_tag, :cmock_tag, :cexception_tag

  def initialize(ceedling_root_path, ceedling_vendor_path=nil)
    @ceedling_install_path = ceedling_root_path.clone()
    @ceedling_tag = read_tag( ceedling_root_path )
    @ceedling_build = read_build( ceedling_root_path )

    # Framework versions are gathered only when asked for
    read_framework_tags( ceedling_vendor_path ) unless ceedling_vendor_path.nil?
  end

  private

  # The tag comes from the installation's own lib/version.rb, never from a loaded constant
  def read_tag(root_path)
    installation = Installation.new( root_path )
    tag = installation.version
    return tag unless tag.nil?

    raise CeedlingException.new( "Could not read a Ceedling version from #{File.join( installation.root, Installation::VERSION_FILE )}" )
  end

  # <TAG>-<SHA> when the installation carries a commit SHA file, otherwise <TAG>
  def read_build(root_path)
    sha_filepath = File.join( root_path, GIT_COMMIT_SHA_FILENAME )
    return @ceedling_tag unless File.exist?( sha_filepath )

    return "#{@ceedling_tag}-#{File.read( sha_filepath ).strip()}"
  end

  # Sets @unity_tag, @cmock_tag and @cexception_tag from each header's version macros
  def read_framework_tags(vendor_path)
    FRAMEWORK_HEADERS.each_pair do |name, path|
      filepath = File.join( vendor_path, path )
      instance_variable_set( "@#{name.downcase}_tag", read_framework_tag( name, filepath ) )
    end
  end

  def read_framework_tag(name, filepath)
    lines = File.readlines( filepath )
  rescue StandardError
    raise CeedlingException.new( "Could not collect version information for vendor component ⏩️ #{filepath}" )
  else
    return framework_version( name, lines )
  end

  # MAJOR.MINOR.BUILD from the header's last definition of each macro, 0 for any missing
  def framework_version(name, lines)
    return ['VERSION_MAJOR', 'VERSION_MINOR', 'VERSION_BUILD'].map do |field|
      matches = lines.filter_map { |line| line.match( /#{name}_#{field}\s+(\d+)/ ) }
      matches.empty? ? '0' : matches.last[1]
    end.join( '.' )
  end
end
