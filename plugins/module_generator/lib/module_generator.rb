require 'ceedling/plugin'
require 'ceedling/constants'
require 'erb'
require 'fileutils'

class ModuleGenerator < Plugin

  attr_reader :config

  def create(module_name, optz={})

    # grab our own reference to the main configuration hash
    @project_config = @ceedling[:configurator].project_config_hash

    # load the generate module script form Unity's collection of scripts.
    require "generate_module.rb" 

    # if asked to destroy, do so. otherwise create (because isn't creating something always better?)
    if ((!optz.nil?) && (optz[:destroy]))
      UnityModuleGenerator.new( divine_options(optz) ).destroy(module_name)
    else
      UnityModuleGenerator.new( divine_options(optz) ).generate(module_name)
    end
  end

  def stub_from_header(module_name, optz={})
    require "cmock.rb" #From CMock
    stuboptz = divine_options(optz)
    pathname = optz[:path_inc] || optz[:path_src] || "src"
    filename = File.expand_path(optz[:module_root_path], File.join(pathname, module_name + ".h"))
    CMock.new(stuboptz).setup_skeletons(filename)
  end

  private

  def divine_options(optz={})
    # Build default configuration based on looking up other values
    unity_generator_options =
    {
      :pattern      => optz[:pattern],
      :test_prefix  => ((defined? PROJECT_TEST_FILE_PREFIX     ) ? PROJECT_TEST_FILE_PREFIX : "Test" ),
      :mock_prefix  => ((defined? CMOCK_MOCK_PREFIX            ) ? CMOCK_MOCK_PREFIX : "Mock" ),
      :includes     => ((defined? MODULE_GENERATOR_INCLUDES    ) ? MODULE_GENERATOR_INCLUDES : {} ),
      :boilerplates => ((defined? MODULE_GENERATOR_BOILERPLATES) ? MODULE_GENERATOR_BOILERPLATES : {} ),
      :naming       => ((defined? MODULE_GENERATOR_NAMING      ) ? MODULE_GENERATOR_NAMING : nil ),
      :update_svn   => ((defined? MODULE_GENERATOR_UPDATE_SVN  ) ? MODULE_GENERATOR_UPDATE_SVN : false ),
      :test_define  => ((defined? MODULE_GENERATOR_TEST_DEFINE ) ? MODULE_GENERATOR_TEST_DEFINE : "TEST" ),
    }

    # Add our lookup paths to this, based on overall project configuration
    if @project_config.include? :paths
      unity_generator_options[:paths_src] = @project_config[:paths][:source]  || [ 'src' ]
      unity_generator_options[:paths_inc] = @project_config[:paths][:include] || @project_config[:paths][:source] || [ 'src' ]
      unity_generator_options[:paths_tst] = @project_config[:paths][:test]    || [ 'test' ]
    else
      unity_generator_options[:paths_src] = [ 'src' ]
      unity_generator_options[:paths_inc] = [ 'src' ]
      unity_generator_options[:paths_tst] = [ 'test' ]
    end

    # Flatten if necessary
    if (unity_generator_options[:paths_src].class == Hash)
      unity_generator_options[:paths_src] = unity_generator_options[:paths_src].values.flatten
    end
    if (unity_generator_options[:paths_inc].class == Hash)
      unity_generator_options[:paths_inc] = unity_generator_options[:paths_inc].values.flatten
    end
    if (unity_generator_options[:paths_tst].class == Hash)
      unity_generator_options[:paths_tst] = unity_generator_options[:paths_tst].values.flatten
    end

    # Read Boilerplate template file.
    if (defined? MODULE_GENERATOR_BOILERPLATE_FILES)

      bf = MODULE_GENERATOR_BOILERPLATE_FILES

      if !bf[:src].nil? && File.exist?(bf[:src])
        unity_generator_options[:boilerplates][:src] = File.read(bf[:src])
      end

      if !bf[:inc].nil? && File.exist?(bf[:inc])
        unity_generator_options[:boilerplates][:inc] = File.read(bf[:inc])
      end

      if !bf[:tst].nil? && File.exist?(bf[:tst])
        unity_generator_options[:boilerplates][:tst] = File.read(bf[:tst])
      end
    end

    # Check if using "create[<module_root>:<module_name>]" optional paths from command line.
    if optz[:module_root_path].to_s.empty?
      # No path specified. Use the first of each list because we have nothing else to base it on
      unity_generator_options[:skeleton_path] = unity_generator_options[:paths_src][0]
      unity_generator_options[:path_src] = unity_generator_options[:paths_src][0]
      unity_generator_options[:path_inc] = unity_generator_options[:paths_inc][0]
      unity_generator_options[:path_tst] = unity_generator_options[:paths_tst][0]
    else
      # A path was specified. Do our best to determine which is the best choice based on this information
      unity_generator_options[:skeleton_path] = @ceedling[:file_finder_helper].find_best_path_in_collection(optz[:module_root_path], unity_generator_options[:path_src], :ignore) || unity_generator_options[:paths_src][0]
      unity_generator_options[:path_src] = @ceedling[:file_finder_helper].find_best_path_in_collection(optz[:module_root_path], unity_generator_options[:path_src], :ignore) || unity_generator_options[:paths_src][0]
      unity_generator_options[:path_inc] = @ceedling[:file_finder_helper].find_best_path_in_collection(optz[:module_root_path], unity_generator_options[:path_inc], :ignore) || unity_generator_options[:paths_inc][0]
      unity_generator_options[:path_tst] = @ceedling[:file_finder_helper].find_best_path_in_collection(optz[:module_root_path], unity_generator_options[:path_tst], :ignore) || unity_generator_options[:paths_tst][0]
    end

    return unity_generator_options
  end

end
