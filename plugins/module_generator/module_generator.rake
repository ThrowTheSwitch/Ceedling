
namespace :module do

  desc "Generate module (source, header and test files)"
    task :create, :module_path do |t, args|
    args[:module_path].split(/,/).each {|v| @ceedling[:module_generator].create(v) }
  end

  desc "Destroy module (source, header and test files)"
  task :destroy, :module_path do |t, args|
    args[:module_path].split(/,/).each {|v| @ceedling[:module_generator].create(v, {:destroy => true}) }
  end

end
