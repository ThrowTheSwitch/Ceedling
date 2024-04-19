# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

module Ceedling
  module Version
    # If this file is loaded, we know it is next to the vendor path to use for version lookups
    vendor_path = File.expand_path( File.join( File.dirname( __FILE__ ), '../../vendor' ) )

    # Anonymous hash
    {
      'UNITY' => File.join( 'unity', 'src', 'unity.h' ),
      'CMOCK' => File.join( 'cmock', 'src', 'cmock.h' ),
      'CEXCEPTION' => File.join( 'c_exception', 'lib', 'CException.h' )
    }.each_pair do |name, path|
      filename = File.join( vendor_path, path )

      # Actually look up the versions
      a = [0,0,0]

      begin
        File.readlines( filename ).each do |line|
          ['VERSION_MAJOR', 'VERSION_MINOR', 'VERSION_BUILD'].each_with_index do |field, i|
            m = line.match(/#{name}_#{field}\s+(\d+)/)
            a[i] = m[1] unless (m.nil?)
          end
        end
      rescue
        raise CeedlingException.new( "Could not collect version information for vendor component: #{filename}" )
      end

      # Splat it to crete the final constant
      eval("#{name} = '#{a.join(".")}'")
    end

    GEM = "1.0.0"
    CEEDLING = GEM

    puts CEEDLING if __FILE__ == $0
  end
end
