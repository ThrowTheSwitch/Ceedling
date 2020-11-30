
# Setup our load path:
[ 
  'lib',
  'test',
  'vendor/behaviors/lib',
  'vendor/hardmock/lib',
].each do |dir|
  $LOAD_PATH.unshift( File.join( File.expand_path(File.dirname(__FILE__) + "/../"), dir) )
end
