
# Setup our load path:
[ 
  'lib',
  'test',
  'vendor/behaviors/lib',
  'vendor/hardmock/lib',
  'vendor/constructor/lib',
  'vendor/deep_merge/lib',
].each do |dir|
  $LOAD_PATH.unshift( File.join( File.expand_path(File.dirname(__FILE__) + "/../"), dir) )
end
