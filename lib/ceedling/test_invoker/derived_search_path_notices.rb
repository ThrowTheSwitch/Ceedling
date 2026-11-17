# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'ceedling/constants'
require 'ceedling/filesystem/project_paths'

# The NOTICE for each search path a test's #includes imply. Each directory is logged once
# a build, however many tests need it, naming the first.
class DerivedSearchPathNotices

  def initialize(loginator:)
    @loginator = loginator
    @noticed   = Set.new
    @lock      = Mutex.new
  end

  def forget
    @lock.synchronize { @noticed.clear }
  end

  def added(testable, root, text, header)
    return unless first?( location( root ) )

    msg = "Added search path '#{root}' for #{testable.filepath} after every configured search path, so \"#{text}\" reaches #{header}."
    @loginator.log( msg, Verbosity::COMPLAIN, LogLabels::NOTICE )
  end

  private

  def first?(key)
    return !@lock.synchronize { @noticed.add?( key ) }.nil?
  end

  # Windows compares paths without regard to case
  def location(path)
    absolute = ProjectPaths.absolute( path )
    return ProjectPaths::WINDOWS ? absolute.downcase : absolute
  end

end
