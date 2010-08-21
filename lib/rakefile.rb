require 'fileutils'

# get directory containing this here file, back up one directory, and expand to full path
CEEDLING_ROOT    = File.expand_path(File.dirname(__FILE__) + '/..')
CEEDLING_LIB     = File.join(CEEDLING_ROOT, 'lib')
CEEDLING_VENDOR  = File.join(CEEDLING_ROOT, 'vendor')
CEEDLING_RELEASE = File.join(CEEDLING_ROOT, 'release')

$LOAD_PATH.unshift( CEEDLING_LIB )
$LOAD_PATH.unshift( File.join(CEEDLING_VENDOR, 'diy/lib') )
$LOAD_PATH.unshift( File.join(CEEDLING_VENDOR, 'constructor/lib') )
$LOAD_PATH.unshift( File.join(CEEDLING_VENDOR, 'cmock/lib') )
$LOAD_PATH.unshift( File.join(CEEDLING_VENDOR, 'deep_merge/lib') )

require 'rake'

require 'diy'
require 'constructor'

require 'constants'


# construct all our objects
@ceedling = DIY::Context.from_yaml( File.read( File.join(CEEDLING_LIB, 'objects.yml') ) )
@ceedling.build_everything

# one-stop shopping for all our setup and whatnot post construction
@ceedling[:setupinator].do_setup(@ceedling, @ceedling[:setupinator].load_project_files)

# set as global constant our discovered project file so it's available for use
# (we don't use it but maybe custom extensions will need it somehow)
CEEDLING_MAIN_PROJECT_FILE = @ceedling[:project_config_manager].main_project_filepath

# control Rake's verbosity
if (not @ceedling[:verbosinator].should_output?(Verbosity::OBNOXIOUS))
  verbose(false) # verbose defaults to true when rake loads
end


@ceedling[:plugin_manager].pre_build


# load rakefile component files (*.rake)
PROJECT_RAKEFILE_COMPONENT_FILES.each do |component|
  load(component)
end


# end block executed following each rake run
END {
	# only run plugins if we got here without runtime exceptions or errors
	if (@ceedling[:system_wrapper].ruby_success)
    
    # save our test configuration to determine configuration changes upon next run
    if (@ceedling[:plugin_reportinator].test_build?)
      @ceedling[:project_config_manager].cache_project_config( @ceedling[:configurator].project_test_build_cache_path, @ceedling[:setupinator].config_hash )
    end
    
    # save our release configuration to determine configuration changes upon next run
    if (@ceedling[:plugin_reportinator].release_build?)
      @ceedling[:project_config_manager].cache_project_config( @ceedling[:configurator].project_release_build_cache_path, @ceedling[:setupinator].config_hash )
    end

	  @ceedling[:plugin_manager].post_build
	  
	  if (@ceedling[:plugin_manager].build_failed?)
	    @ceedling[:plugin_manager].print_build_failures
	    exit(1)
	  end
	end
}
