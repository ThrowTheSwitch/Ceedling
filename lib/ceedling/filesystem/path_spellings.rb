# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'ceedling/filesystem/project_paths'

# A place reached through a symlink has two spellings: as listed and as it really is.
# Collection compares places by both, and measures how far one lies below another.
module PathSpellings

  # A path as compared: Windows compares paths without regard to case
  def self.key(path)
    return ProjectPaths::WINDOWS ? path.downcase : path
  end

  # Both spellings of each of `paths`, as compared, so either reaches it
  def self.of(paths)
    return Set.new( paths.flat_map { |path| [ProjectPaths.absolute( path ), ProjectPaths.real_absolute( path )] }.map { |path| key( path ) } )
  end

  # How many directories above a place, by any of `spellings` of it, the nearest one in
  # `spelled` lies: 0 for the place itself, or infinity for none
  def self.nearer(spellings, spelled)
    return Float::INFINITY if spelled.empty?

    return spellings.map { |path| distance( path, spelled ) }.min
  end

  # `paths`, found below `base`, respelled below the base's real path
  def self.through_real(paths, base)
    real = ProjectPaths.real_absolute( base )
    return paths if base == real

    return paths.map { |path| ProjectPaths.same?( path, base ) || ProjectPaths.starts_with?( path, "#{base}/" ) ? real + path[base.length..] : path }
  end

  def self.distance(path, spelled)
    steps = 0
    loop do
      return steps if spelled.include?( key( path ) )

      parent = File.dirname( path )
      return Float::INFINITY if parent == path

      path   = parent
      steps += 1
    end
  end
  private_class_method :distance

end
