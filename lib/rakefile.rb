require 'fileutils'

# 1. get directory containing this here file, back up one directory, and expand to full path
# 2. lop off current working directory from the root of Ceedling
# (the root of the file system, particularly with Windows, can show up in unexpected places and cause trouble)
ceedling_root           = File.expand_path(File.dirname(__FILE__) + '/..')
ceedling_root_truncated = ceedling_root.sub(/#{Regexp.escape(FileUtils.getwd)}/i, '')
ceedling_root_truncated = ceedling_root_truncated[1..-1] if (ceedling_root_truncated[0..0] == '/') if (ceedling_root != ceedling_root_truncated)

# add trailing '/' as long as adding that '/' doesn't equal root of file system
CEEDLING_ROOT    = ceedling_root_truncated + (ceedling_root_truncated.empty? ? '' : '/')
CEEDLING_LIB     = CEEDLING_ROOT + 'lib/'
CEEDLING_VENDOR  = CEEDLING_ROOT + 'vendor/'
CEEDLING_RELEASE = CEEDLING_ROOT + 'release/'

$LOAD_PATH.unshift( CEEDLING_LIB )
$LOAD_PATH.unshift( CEEDLING_VENDOR + 'diy/lib' )
$LOAD_PATH.unshift( CEEDLING_VENDOR + 'constructor/lib' )
$LOAD_PATH.unshift( CEEDLING_VENDOR + 'cmock/lib' )
$LOAD_PATH.unshift( CEEDLING_VENDOR + 'deep_merge/lib' )

require 'rake'

require 'diy'
require 'constructor'

require 'constants'


# construct all our objects
@ceedling = DIY::Context.from_yaml( File.read(CEEDLING_LIB + 'objects.yml') )
@ceedling.build_everything

# one-stop shopping for all our setup and whatnot post construction
@ceedling[:setupinator].do_setup(@ceedling, @ceedling[:setupinator].load_project_files)

# set as global constant our discovered project file so it's available for use
# (we don't use it but maybe custom extensions will need it somehow)
CEEDLING_MAIN_PROJECT_FILE = @ceedling[:project_file_loader].main_project_filepath


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
	# only run plugin if we got to it without runtime exceptions or errors
	if (@ceedling[:system_wrapper].ruby_success)
	  @ceedling[:plugin_manager].post_build
	  
	  if (@ceedling[:plugin_manager].build_failed?)
	    @ceedling[:plugin_manager].print_build_failures
	    exit(1)
	  end
	end
}
