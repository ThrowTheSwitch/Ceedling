CEEDLING_LIB    = File.expand_path(File.dirname(__FILE__)) + '/'
CEEDLING_ROOT   = File.expand_path( CEEDLING_LIB + '..' ) + '/'
CEEDLING_VENDOR = File.expand_path( CEEDLING_ROOT + 'vendor' ) + '/'

$LOAD_PATH.unshift( CEEDLING_LIB )
$LOAD_PATH.unshift( CEEDLING_VENDOR + '../vendor/diy/lib' )
$LOAD_PATH.unshift( CEEDLING_VENDOR + '../vendor/constructor/lib' )
$LOAD_PATH.unshift( CEEDLING_VENDOR + '../vendor/cmock/lib' )
$LOAD_PATH.unshift( CEEDLING_VENDOR + '../vendor/deep_merge/lib' )

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
  @objects[:extendinator].post_build
  
  if (@objects[:extendinator].build_failed?)
    @objects[:extendinator].print_build_failures
    exit(1)
  end
}
