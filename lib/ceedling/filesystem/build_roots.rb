# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Loaded eagerly: Digest's lazy autoload is not thread-safe, and build threads form paths
require 'digest/sha2'
require 'ceedling/filesystem/project_paths'
require 'ceedling/filesystem/build_subpath'

# Which configured roots a build path spells by a short marker instead of their whole
# location, and what each marker is.
#
# A build file sits below the build directory at its source's path from the project root
# (see BuildSubpath). For a source below a long root, such as a vendor's include directory
# far outside the project, most of that path is the root's own location, which no build
# step reads. Such a root is replaced by `_<name>_<hash>`: its own directory name, then 8
# hex digits of SHA-256 of its encoded spelling. Everything below the root keeps its path.
#
# Only the outermost of nested roots counts, so a whole tree shares one marker, and a root
# is shortened only when its marker is shorter than its encoded spelling. The decision
# depends on nothing but the root's spelling, so it holds from run to run.
module BuildRoots

  HASH_LENGTH = 8

  # A build subpath's first segment shaped like a marker. Only a table says whether it is one.
  MARKER = /\A_[^_\/][^\/]*_[0-9A-F]{#{HASH_LENGTH}}\z/

  # The roots shortened, and their markers
  class Table

    attr_reader :digest

    def initialize(markers)
      @markers   = markers.freeze
      @roots     = markers.invert.freeze
      @absolutes = markers.keys.to_h { |root| [root, ProjectPaths.absolute( root )] }.freeze
      @digest    = markers.map { |root, marker| "#{marker}=#{root}" }.join( "\n" ).freeze
      freeze
    end

    def marker_for(root) = @markers[root]

    def root_for(marker) = @roots[marker]

    # The shortened root holding an absolute path, if any. Roots are outermost, so at most one does.
    def containing(full)
      return @absolutes.find { |_root, absolute| ProjectPaths.contains?( absolute, full ) }&.first
    end

    # Each shortened root and its marker, in configuration order
    def entries = @markers.to_a

    def empty? = @markers.empty?

  end

  # The table for canonical root spellings, as configuration collects them
  def self.table(roots, windows: ProjectPaths::WINDOWS)
    return Table.new( candidates( roots, windows ).uniq { |_root, marker| marker }.to_h )
  end

  # Pairs of distinct roots whose markers would be the same
  def self.collisions(roots, windows: ProjectPaths::WINDOWS)
    return candidates( roots, windows ).group_by { |_root, marker| marker }.values
             .select { |group| group.length > 1 }
             .flat_map { |group| group.map( &:first ).combination( 2 ).to_a }
  end

  # The outermost roots worth shortening, each with its marker
  def self.candidates(roots, windows)
    # Two spellings of one place are one root
    return outermost( roots.map( &:to_s ).uniq { |root| ProjectPaths.absolute( root ) } ).filter_map do |root|
      encoded = BuildSubpath.encode( root )
      # A file Ceedling ships is already placed briefly below `_ceedling_`
      next if encoded.start_with?( BuildSubpath::INSTALLED_SEGMENT )

      marker = marker( root, encoded, windows )
      [root, marker] if marker.length < encoded.length
    end
  end

  def self.outermost(roots)
    absolutes = roots.to_h { |root| [root, ProjectPaths.absolute( root )] }

    return roots.reject do |root|
      absolutes.any? { |other, absolute| other != root && ProjectPaths.contains?( absolute, absolutes[root] ) }
    end
  end

  def self.marker(root, encoded, windows)
    key  = windows ? encoded.downcase : encoded
    name = ProjectPaths.segments( ProjectPaths.absolute( root ) ).last.to_s.delete( ':' ).sub( /\A_+/, '' )
    name = 'root' if name.empty?

    return "_#{name}_#{Digest::SHA256.hexdigest( key )[0, HASH_LENGTH].upcase}"
  end

  private_class_method :candidates, :outermost, :marker

end
