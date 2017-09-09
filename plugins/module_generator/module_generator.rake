
namespace :module do

  module_root_path_separator = ':'

  desc "Generate module (source, header and test files)"
  task :create, :module_path do |t, args|
    files = [args[:module_path]] + (args.extras || [])
    optz = {}
    ["dh", "dih", "mch", "mvp", "src", "test"].each do |pat|
      p = files.delete(pat)
      optz[:pattern] = p unless p.nil?
    end
    files.each {
      |v|
      module_root_path, module_name = v.split(module_root_path_separator, 2)
      @ceedling[:module_generator].create(module_name, module_root_path, optz)
    }
  end

  desc "Destroy module (source, header and test files)"
  task :destroy, :module_path do |t, args|
    files = [args[:module_path]] + (args.extras || [])
    optz = { :destroy => true }
    ["dh", "dih", "mch", "mvp", "src", "test"].each do |pat|
      p = files.delete(pat)
      optz[:pattern] = p unless p.nil?
    end
    files.each {
      |v|
      module_root_path, module_name = v.split(module_root_path_separator, 2)
      @ceedling[:module_generator].create(module_name, module_root_path, optz)
    }
  end

end
