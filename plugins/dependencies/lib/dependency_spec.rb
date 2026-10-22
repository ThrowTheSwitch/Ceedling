# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

# One configured dependency, validated and normalized.
#
# Each dependency names its paths under :paths, and each path falls back to another when
# left out: :source and :fetch to each other, :build to :source then :fetch, :artifact to
# :build. With none configured, every path is `dependencies/<task name>`. Artifacts
# (libraries, executables, includes, sources) live under the artifact path. An optional
# :deploy path receives deployed copies.
#
# The task name is the configured name's word characters, which `dependencies:*` tasks
# use, so it must be non-empty and unique among dependencies.
class DependencySpec

  FETCH_METHODS = %i[none zip tar_gzip git svn custom].freeze

  # Fetch methods that read from a configured :source
  SOURCED = %i[zip tar_gzip git svn].freeze

  # Include entries that are globs or add/subtract notation rather than plain paths
  INCLUDE_GLOB = /(?:\A[+-]:)|(?:\*\*)/

  attr_reader :name, :task_name, :fetch

  def self.build_all(deps)
    specs = deps.map { |dep| new( dep ) }

    specs.group_by( &:task_name ).each do |task_name, same|
      next if same.size == 1

      names = same.map { |spec| "`#{spec.name}`" }.join( ' and ' )
      raise CeedlingException.new( "Dependencies #{names} share the task name #{task_name}. Give them distinct names." )
    end

    return specs
  end

  def initialize(dep)
    @dep       = dep
    @name      = dep[:name] or raise CeedlingException.new( 'Each dependency must have a :name.' )
    @task_name = task_name_for( @name )
    @fetch     = dep[:fetch] || {}
    @paths     = dep[:paths] || {}
    @artifacts = dep[:artifacts] || {}

    problem = fetch_problem
    raise CeedlingException.new( problem ) unless problem.nil?

    freeze
  end

  # Settings given as lists, each empty when left out
  def build_steps = Array( @dep[:build] )
  def environment = Array( @dep[:environment] )
  def defines     = Array( @dep[:defines] )
  def flags       = Array( @dep[:flags] )
  def libraries   = Array( @dep[:libraries] )
  def libpaths    = Array( @dep[:libpaths] )

  def fetch_method
    return @fetch[:method]
  end

  def fetch_path    = @paths[:fetch] || @paths[:source] || default_path
  def source_path   = @paths[:source] || @paths[:fetch] || default_path
  def build_path    = @paths[:build] || @paths[:source] || @paths[:fetch] || default_path
  def artifact_path = @paths[:artifact] || @paths[:build] || default_path

  # Every configured path, for cleaning a fetched dependency away, or only the artifact
  # path, for cleaning one that is not fetched. The artifact path never includes the
  # source path, which a dependency that is not fetched keeps.
  def working_paths(artifacts_only: false)
    return [artifact_path] - [source_path, fetch_path] if artifacts_only

    paths = @paths.except( :deploy ).values.compact.uniq
    return paths.empty? ? [default_path] : paths
  end

  # Where deploying copies dynamic libraries and executables, never cleaned away
  def deploy_path(default)
    return @paths[:deploy] || default
  end

  # Search paths a dependency's undocumented :source and :include keys add to `:build_lib`
  def build_lib_search_paths
    return (Array( @dep[:source] ) + Array( @dep[:include] )).compact.uniq
  end

  # Static libraries as configured, relative to the artifact path
  def static_library_entries = Array( @artifacts[:static_libraries] )

  def static_libraries  = artifacts( :static_libraries )
  def dynamic_libraries = artifacts( :dynamic_libraries )
  def executables       = artifacts( :executables )
  def include_files     = artifacts( :includes )
  def source_paths      = artifacts( :source )

  # Directories to search for this dependency's headers. A header names its directory, a
  # glob expands through `collector` against the disk, and anything else is a directory.
  def include_directories(collector)
    return Array( @artifacts[:includes] ).flat_map do |include|
      path = File.join( artifact_path, include )
      if include.end_with?( '.h' ) then [File.dirname( path )]
      elsif include.match?( INCLUDE_GLOB ) then collector.call( path )
      else [path]
      end
    end.uniq
  end

  private

  def task_name_for(name)
    task_name = name.to_s.gsub( /\W/, '' )
    return task_name unless task_name.empty?

    raise CeedlingException.new( "Dependency name `#{name}` needs letters or digits for its task name." )
  end

  def default_path
    return File.join( 'dependencies', @task_name )
  end

  def artifacts(kind)
    return Array( @artifacts[kind] ).map { |path| File.join( artifact_path, path ) }
  end

  # What is wrong with the fetch configuration, or nil
  def fetch_problem
    method = fetch_method
    return nil if method.nil?
    return "Unknown fetch method `#{method}` for dependency `#{@name}`." unless FETCH_METHODS.include?( method )
    return "Fetch method :#{method} for dependency `#{@name}` needs a :source." if SOURCED.include?( method ) and @fetch[:source].to_s.empty?
    return "Fetch method :custom for dependency `#{@name}` needs :executable commands." if method == :custom and Array( @fetch[:executable] ).empty?

    return nil
  end

end
