require 'fileutils'

# 1. get directory containing this here file, back up one directory, and expand to full path
# 2. lop off current working directory from the root of Ceedling
# (the root of the file system, particularly in Windows, can show up in unexpected places and cause trouble)
ceedling_root           = File.expand_path(File.dirname(__FILE__) + '/..')
ceedling_root_truncated = ceedling_root.sub(Regexp.escape(FileUtils.getwd), '')
ceedling_root_truncated = ceedling_root_truncated[1..-1] if (ceedling_root_truncated[0..0] == '/')

CEEDLING_ROOT   = ceedling_root_truncated + '/'
CEEDLING_LIB    = CEEDLING_ROOT + 'lib/'
CEEDLING_VENDOR = CEEDLING_ROOT + 'vendor/'

$LOAD_PATH.unshift( CEEDLING_LIB )
$LOAD_PATH.unshift( CEEDLING_VENDOR + 'diy/lib' )
$LOAD_PATH.unshift( CEEDLING_VENDOR + 'constructor/lib' )
$LOAD_PATH.unshift( CEEDLING_VENDOR + 'cmock/lib' )
$LOAD_PATH.unshift( CEEDLING_VENDOR + 'deep_merge/lib' )

require 'rake'
require 'rake/clean'

require 'diy'
require 'constructor'

require 'constants'

# construct all our objects
@objects = DIY::Context.from_yaml( File.read(CEEDLING_LIB + 'objects.yml') )
@objects.build_everything

# one-stop shopping for all our setup and whatnot post construction
@objects[:setupinator].do_setup(@objects)


# set as global constant our discovered project file so it's available for use
# (we don't use it but maybe custom extensions will need it somehow)
CEEDLING_MAIN_PROJECT_FILE = @objects[:project_file_loader].main_project_filepath


# control Rake's verbosity
if (not @objects[:verbosinator].should_output?(Verbosity::OBNOXIOUS))
  verbose(false) # verbose defaults to true when rake loads
end


# load rakefile component files (*.rake)
PROJECT_RAKEFILE_COMPONENT_FILES.each do |component|
  load(component)
end


# end block executed following each rake run
END {
  @objects[:plugin_manager].post_build
  
  if (@objects[:plugin_manager].build_failed?)
    @objects[:plugin_manager].print_build_failures
    exit(1)
  end
}
