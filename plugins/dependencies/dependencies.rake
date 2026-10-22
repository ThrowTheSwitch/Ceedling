# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

@ceedling[DEPENDENCIES_SYM].specs.each do |dep|

  # The plugin creates each working path as fetching and building need it. Created any
  # earlier, a build path inside the fetch path would make an unfetched dependency look
  # fetched and stop a git clone into it.

  collector = @ceedling[DEPENDENCIES_SYM].path_collector
  headers_and_sources = dep.include_directories( collector ) + dep.include_files + dep.source_paths
  all_deps = dep.static_libraries + dep.dynamic_libraries + headers_and_sources

  # Add a rule for building the actual libraries and executables from dependency list
  (dep.static_libraries + dep.dynamic_libraries + dep.executables).each do |libpath|
    file libpath do |filetask|
      path = filetask.name

      # We double-check that it doesn't already exist, because this process sometimes
      # produces multiple files, but they may have already been flagged as invoked
      if (File.exist?(path))
        @ceedling[:loginator].lazy( Verbosity::OBNOXIOUS ) { "Nothing to do for dependency #{path}" }
      else
        @ceedling[DEPENDENCIES_SYM].make_if_required(path)
      end
    end
  end

  # Add a rule for building the source and includes from dependency list
  # A task's name is the project path the dependency is found by
  headers_and_sources.each do |libpath|
    task libpath do |filetask|
      path = filetask.name

      if File.exist?( path )
        @ceedling[:loginator].lazy( Verbosity::OBNOXIOUS ) { "Nothing to do for dependency #{path}" }
      else
        @ceedling[DEPENDENCIES_SYM].make_if_required(path)
      end
    end
  end

  # Give ourselves a way to trigger individual dependencies
  namespace DEPENDENCIES_SYM do
    namespace :deploy do
      # Add task to directly just build this dependency
      task(dep.task_name => dep.dynamic_libraries + dep.executables) do |_t,_args|
        @ceedling[DEPENDENCIES_SYM].deploy_if_required(dep.task_name)
      end
    end

    namespace :make do
      # Add task to directly just build this dependency
      task(dep.task_name => all_deps + dep.executables)
    end

    namespace :clean do
      # Add task to directly clobber this dependency
      task(dep.task_name) do
        @ceedling[DEPENDENCIES_SYM].clean_if_required(dep.task_name)
      end
    end

    namespace :fetch do
      # Add task to directly clobber this dependency
      task(dep.task_name) do
        @ceedling[DEPENDENCIES_SYM].fetch_if_required(dep.task_name)
      end
    end
  end


  # Add source files to our list of things to build during release
  task PROJECT_RELEASE_BUILD_TARGET => dep.source_paths

  # Finally, add the static libraries to our RELEASE build dependency list
  task RELEASE_SYM => dep.static_libraries

  # Add the dynamic libraries to our RELEASE task dependency list so that they will be copied automatically
  task RELEASE_SYM => dep.dynamic_libraries

  # A release may ship a dependency's executables, which no test build links
  task RELEASE_SYM => dep.executables

  task :prepare => all_deps
end

# Dependency libraries join the library names and paths test and release builds link with
link_libraries = @ceedling[DEPENDENCIES_SYM].link_libraries
PATHS_LIBRARIES ||= []
PATHS_LIBRARIES.concat( link_libraries[:paths] ).uniq!
LIBRARIES_SYSTEM ||= []
LIBRARIES_SYSTEM.concat( link_libraries[:names] ).uniq!

# Add any artifact:include or :source folders to our release & test includes paths so linking and mocking work.
@ceedling[DEPENDENCIES_SYM].add_headers_and_sources()

# Add tasks for building or cleaning ALL depencies
namespace DEPENDENCIES_SYM do
  task_names = @ceedling[DEPENDENCIES_SYM].specs.map( &:task_name )

  desc "Deploy missing dependencies."
  task :deploy => task_names.map { |name| "#{DEPENDENCIES_SYM}:deploy:#{name}" }

  desc "Build any missing dependencies."
  task :make => task_names.map { |name| "#{DEPENDENCIES_SYM}:make:#{name}" }

  desc "Clean all dependencies."
  task :clean => task_names.map { |name| "#{DEPENDENCIES_SYM}:clean:#{name}" }

  desc "Fetch all dependencies."
  task :fetch => task_names.map { |name| "#{DEPENDENCIES_SYM}:fetch:#{name}" }
end

namespace :files do
  desc "List all collected dependency libraries and executables."
  task :dependencies do
    puts "dependency files:"
    deps = @ceedling[DEPENDENCIES_SYM].specs.flat_map { |dep| dep.static_libraries + dep.dynamic_libraries + dep.executables }
    deps.sort.each {|dep| puts " - #{dep}"}
    puts "file count: #{deps.size}"
  end
end
