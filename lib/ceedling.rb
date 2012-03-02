require 'rake'

def ceedling_dir
  File.join(
    File.dirname(__FILE__),
    '..')
end

def builtin_ceedling_plugins_path
  File.join(
    ceedling_dir,
    'plugins')
end

load File.join(
  ceedling_dir,
  'lib',
  'rakefile.rb')
