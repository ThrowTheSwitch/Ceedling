
namespace :module do

  desc "Generate module (source, header and test files)"
  task :create, :module_path do |t, args|
    args = args[:module_path].split(/,/)
    optz = {}
    ["dh", "dih", "mch", "mvp"].each do |pat|
      p = args.delete(pat)
      optz[:pattern] = p unless p.nil?
    end
    args.each {|v| @ceedling[:module_generator].create(v, optz) }
  end

  desc "Destroy module (source, header and test files)"
  task :destroy, :module_path do |t, args|
    args = args[:module_path].split(/,/)
    optz = { :destroy => true }
    ["dh", "dih", "mch", "mvp"].each do |pat|
      p = args.delete(pat)
      optz[:pattern] = p unless p.nil?
    end
    args.each {|v| @ceedling[:module_generator].create(v, optz) }
  end

end
