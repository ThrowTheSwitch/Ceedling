
namespace :module do

  desc "Generate module (source, header and test files)"
  task :create, :module_path do |t, args|
    files = [args[:module_path]] + (args.extras || [])
    optz = {}
    ["dh", "dih", "mch", "mvp", "src", "test"].each do |pat|
      p = files.delete(pat)
      optz[:pattern] = p unless p.nil?
    end
    files.each {|v| @ceedling[:module_generator].create(v, optz) }
  end

  desc "Destroy module (source, header and test files)"
  task :destroy, :module_path do |t, args|
    files = [args[:module_path]] + (args.extras || [])
    optz = { :destroy => true }
    ["dh", "dih", "mch", "mvp", "src", "test"].each do |pat|
      p = files.delete(pat)
      optz[:pattern] = p unless p.nil?
    end
    files.each {|v| @ceedling[:module_generator].create(v, optz) }
  end

end
