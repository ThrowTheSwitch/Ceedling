PROJECT_ROOT  = File.expand_path( File.dirname(__FILE__) )

load '../../lib/rakefile.rb'

task :default => [:clobber, 'test:all']
