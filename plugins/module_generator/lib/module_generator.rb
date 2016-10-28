require 'ceedling/plugin'
require 'ceedling/constants'
require 'erb'
require 'fileutils'

class ModuleGenerator < Plugin

  attr_reader :config

  def create(module_name, optz={})

    require "generate_module.rb" #From Unity Scripts

    if ((!optz.nil?) && (optz[:destroy]))
      UnityModuleGenerator.new( divine_options(optz) ).destroy(module_name)
    else
      UnityModuleGenerator.new( divine_options(optz) ).generate(module_name)
    end
  end

  private

  def divine_options(optz={})
    {
      :path_src => MODULE_GENERATOR_SOURCE_ROOT.gsub('\\', '/').sub(/^\//, '').sub(/\/$/, ''),
      :path_inc => MODULE_GENERATOR_SOURCE_ROOT.gsub('\\', '/').sub(/^\//, '').sub(/\/$/, ''),
      :path_tst => MODULE_GENERATOR_TEST_ROOT.gsub('\\', '/').sub(/^\//, '').sub(/\/$/, ''),
      :pattern => optz[:pattern],
    }
  end

end
