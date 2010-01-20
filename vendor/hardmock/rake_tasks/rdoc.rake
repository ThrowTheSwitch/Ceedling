require 'rake/rdoctask'
require File.expand_path(File.dirname(__FILE__) + "/rdoc_options.rb")

namespace :doc do

  desc "Generate RDoc documentation"
  Rake::RDocTask.new { |rdoc|
    rdoc.rdoc_dir = 'doc'
    rdoc.title    = "Hardmock: Strict expectation-based mock object library " 
    add_rdoc_options(rdoc.options)
    rdoc.rdoc_files.include('lib/**/*.rb', 'README','CHANGES','LICENSE')
  }

  task :show => [ 'doc:rerdoc' ] do
    sh "open doc/index.html"
  end

end

