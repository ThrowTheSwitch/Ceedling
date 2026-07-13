# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'


class ReleaseInvoker

  constructor :configurator, :batchinator, :reportinator, :loginator, :rake_wrapper, :file_path_utils, :file_wrapper

  def collect_release_build_objects()
    objects = []

    @batchinator.build_step( "Determining Objects to be Built", heading: false ) do
      objects.concat(
        @file_path_utils.form_release_build_objects_filelist(
          @configurator.collection_release_build_input
        )
      )

      objects.concat(
        @file_path_utils.form_release_build_objects_filelist(
          @configurator.collection_release_artifact_extra_link_objects
        )
      )
    end

    return objects    
  end

  def setup_and_invoke_objects( files )
    objects = @file_path_utils.form_release_build_objects_filelist( files )

    @batchinator.build_step( "Building Objects" ) do
      @batchinator.exec(workload: :compile, things: objects) do |object|
        @rake_wrapper[object].invoke
      end    
    end

    return objects
  end

  def setup_and_invoke_binary( filepath )
    @batchinator.build_step( "Building Binary" ) do
      @rake_wrapper[filepath].invoke
    end

    banner = @reportinator.generate_banner(
      @loginator.decorate( File.basename( filepath ), LogLabels::TITLE )
    )
    @loginator.log( "\n" + banner + "\n" )
  end

  def artifactinate( *files )
    files.flatten.each do |file|
      @file_wrapper.cp( file, @configurator.project_release_artifacts_path ) if @file_wrapper.exist?( file )
    end
  end

  def convert_libraries_to_arguments(libraries)
    args =
      (libraries || []) + 
      ((defined? LIBRARIES_SYSTEM) ? LIBRARIES_SYSTEM : []) +
      ((defined? LIBRARIES_RELEASE) ? LIBRARIES_RELEASE : [])

    args.flatten!
    args.compact!

    if (defined? LIBRARIES_FLAG)
      args.map! {|v| LIBRARIES_FLAG.gsub(/\$\{1\}/, v) }
    end

    return args
  end

  def get_library_paths_to_arguments()
    paths = (defined? PATHS_LIBRARIES) ? (PATHS_LIBRARIES || []).clone : []
    if (defined? LIBRARIES_PATH_FLAG)
      paths.map! {|v| LIBRARIES_PATH_FLAG.gsub(/\$\{1\}/, v) }
    end
    return paths
  end

  def sort_objects_and_libraries(both)
    extension = if ((defined? EXTENSION_SUBPROJECTS) && (defined? EXTENSION_LIBRARIES))
      extension_libraries = if (EXTENSION_LIBRARIES.class == Array)
                              EXTENSION_LIBRARIES.join(")|(?:\\")
                            else
                              EXTENSION_LIBRARIES
                            end
      "(?:\\#{EXTENSION_SUBPROJECTS})|(?:\\#{extension_libraries})"
    elsif (defined? EXTENSION_SUBPROJECTS)
      "\\#{EXTENSION_SUBPROJECTS}"
    elsif (defined? EXTENSION_LIBRARIES)
      if (EXTENSION_LIBRARIES.class == Array)
        "(?:\\#{EXTENSION_LIBRARIES.join(")|(?:\\")})"
      else
        "\\#{EXTENSION_LIBRARIES}"
      end
    else
      "\\.LIBRARY"
    end
    sorted_objects = both.group_by {|v| v.match(/.+#{extension}$/) ? :libraries : :objects }
    libraries = sorted_objects[:libraries] || []
    objects   = sorted_objects[:objects]   || []
    return objects, libraries
  end
end
