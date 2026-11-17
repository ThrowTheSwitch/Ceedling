# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'ceedling/constants'
require 'ceedling/includes/includes'
require 'ceedling/filesystem/project_paths'

# The NOTICEs for the search paths a test's #includes imply: each directory added, and
# each header outside the project a bare name can't reach. Each is logged once a build,
# however many tests run into it, naming the first.
class DerivedSearchPathNotices

  def initialize(configurator:, loginator:)
    @configurator = configurator
    @loginator    = loginator
    @noticed      = Set.new
    @lock         = Mutex.new
  end

  def forget
    @lock.synchronize { @noticed.clear }
  end

  def added(testable, root, text, header)
    return unless first?( [:root, location( root )] )

    msg = "Added search path '#{root}' for #{testable.filepath} after every configured search path, so \"#{text}\" reaches #{header}."
    @loginator.log( msg, Verbosity::COMPLAIN, LogLabels::NOTICE )
  end

  # Gives no directory
  def refused(testable, include, header)
    return nil unless first?( [:refused, location( header )] )

    written   = include.filepath
    suggested = File.join( File.basename( File.dirname( header ) ), File.basename( written ) )
    @loginator.log( refusal( testable, written, header, suggested, include.is_a?( MockInclude ) ), Verbosity::COMPLAIN, LogLabels::NOTICE )
    return nil
  end

  private

  # Without :mock_name_include_folder a mock includes its header by name alone, whatever
  # folder its own #include writes
  def refusal(testable, written, header, suggested, mock)
    opening = "#include \"#{written}\" in #{testable.filepath} names #{header}, outside the project. "
    unless mock and !@configurator.cmock_mock_name_include_folder
      return opening + "Ceedling adds no search path for a bare name there. " \
                       "Include it by its path below an include directory, as in \"#{suggested}\"."
    end

    return opening + "With :cmock ↳ :mock_name_include_folder disabled, its mock includes it by bare name, " \
                     "and Ceedling adds no search path for a bare name there. " \
                     "Enable that option to include it by its folder, as in \"#{suggested}\"."
  end

  def first?(key)
    return !@lock.synchronize { @noticed.add?( key ) }.nil?
  end

  # Windows compares paths without regard to case
  def location(path)
    absolute = ProjectPaths.absolute( path )
    return ProjectPaths::WINDOWS ? absolute.downcase : absolute
  end

end
