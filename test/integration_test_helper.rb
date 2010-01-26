require File.expand_path(File.dirname(__FILE__)) + "/../config/test_environment"
require 'test_helper'
require 'constructor'
require 'hardmock'


class Test::Unit::TestCase
  extend Behaviors
  
  def rake_setup(rake_wrapper_file, *mocks_list)
    # create mocks rules will use
    objects = create_mocks(*mocks_list)
    # create & assign instance of rake
    @rake = Rake::Application.new
    Rake.application = @rake
    
    # tell rake to be verbose in its tracing output
    # (hard to do otherwise since our tests are run from within a rake instance around this one)
    Rake.application.options.trace_rules = true

    # load rakefile wrapper that loads actual rules
    load File.join(TESTS_ROOT, rake_wrapper_file)
    
    # provide the mock objects to the rakefile instance under test
    @rake['inject'].invoke(objects)        
  end
  
  def redefine_global_constant(constant, value)
    $config_options[constant.downcase.to_sym].replace(value)
  end
  
end


