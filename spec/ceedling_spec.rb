require 'spec_helper'
require 'ceedling'

describe 'Ceedling' do
  context 'location' do
    it 'should return the location of the ceedling gem directory' do
      # create test state/variables
      ceedling_path = File.join(File.dirname(__FILE__), '..').gsub('spec','lib')
      # mocks/stubs/expected calls
      # execute method
      location = Ceedling.location
      # validate results
      expect(location).to eq(ceedling_path)
    end
  end

  context 'load_path' do
    it 'should return the location of the plugins directory' do
      # create test state/variables
      load_path = File.join(File.dirname(__FILE__), '..').gsub('spec','lib')
      load_path = File.join( load_path, 'plugins' )
      # mocks/stubs/expected calls
      # execute method
      location = Ceedling.load_path
      # validate results
      expect(location).to eq(load_path)
    end
  end

  context 'rakefile' do
    it 'should return the location of the ceedling rakefile' do
      # create test state/variables
      rakefile_path = File.join(File.dirname(__FILE__), '..').gsub('spec','lib')
      rakefile_path = File.join( rakefile_path, 'lib', 'ceedling', 'rakefile.rb' )
      # mocks/stubs/expected calls
      # execute method
      location = Ceedling.rakefile
      # validate results
      expect(location).to eq(rakefile_path)
    end
  end

  context 'load_project' do
    it 'should load the project with the default yaml file' do
      # create test state/variables
      ENV.delete('CEEDLING_MAIN_PROJECT_FILE')
      rakefile_path = File.join(File.dirname(__FILE__), '..').gsub('spec','lib')
      rakefile_path = File.join( rakefile_path, 'lib', 'ceedling', 'rakefile.rb' )
      # mocks/stubs/expected calls
      expect(Ceedling).to receive(:load).with(rakefile_path)
      # execute method
      Ceedling.load_project
      # validate results
      expect(ENV['CEEDLING_MAIN_PROJECT_FILE']).to eq('./project.yml')
    end

    it 'should load the project with the specified yaml file' do
      # create test state/variables
      ENV.delete('CEEDLING_MAIN_PROJECT_FILE')
      rakefile_path = File.join(File.dirname(__FILE__), '..').gsub('spec','lib')
      rakefile_path = File.join( rakefile_path, 'lib', 'ceedling', 'rakefile.rb' )
      # mocks/stubs/expected calls
      expect(Ceedling).to receive(:load).with(rakefile_path)
      # execute method
      Ceedling.load_project(config: './foo.yml')
      # validate results
      expect(ENV['CEEDLING_MAIN_PROJECT_FILE']).to eq('./foo.yml')
    end

    it 'should load the project with the yaml file specified by the existing environment variable' do
      # create test state/variables
      ENV['CEEDLING_MAIN_PROJECT_FILE'] = './bar.yml'
      rakefile_path = File.join(File.dirname(__FILE__), '..').gsub('spec','lib')
      rakefile_path = File.join( rakefile_path, 'lib', 'ceedling', 'rakefile.rb' )
      # mocks/stubs/expected calls
      expect(Ceedling).to receive(:load).with(rakefile_path)
      # execute method
      Ceedling.load_project
      # validate results
      expect(ENV['CEEDLING_MAIN_PROJECT_FILE']).to eq('./bar.yml')
    end

    it 'should load the project with the specified plugins enabled' do
      # create test state/variables
      DEFAULT_CEEDLING_CONFIG[:plugins][:enabled].clear()
      DEFAULT_CEEDLING_CONFIG[:plugins][:load_paths].clear()
      spec_double = double('spec-double')
      rakefile_path = File.join(File.dirname(__FILE__), '..').gsub('spec','lib')
      rakefile_path = File.join( rakefile_path, 'lib', 'ceedling', 'rakefile.rb' )
      # mocks/stubs/expected calls
      expect(Gem::Specification).to receive(:find_by_name).with('ceedling-foo').and_return(spec_double)
      expect(spec_double).to receive(:gem_dir).and_return('dummy/path')
      expect(Ceedling).to receive(:require).with('ceedling/defaults')
      expect(Ceedling).to receive(:load).with(rakefile_path)
      # execute method
      Ceedling.load_project( config:  './foo.yml',
                             plugins: ['foo'])
      # validate results
      expect(ENV['CEEDLING_MAIN_PROJECT_FILE']).to eq('./foo.yml')
    end

    it 'should set the project root if the root key is provided' do
      # create test state/variables
      Object.send(:remove_const, :PROJECT_ROOT)
      DEFAULT_CEEDLING_CONFIG[:plugins][:enabled].clear()
      DEFAULT_CEEDLING_CONFIG[:plugins][:load_paths].clear()
      rakefile_path = File.join(File.dirname(__FILE__), '..').gsub('spec','lib')
      rakefile_path = File.join( rakefile_path, 'lib', 'ceedling', 'rakefile.rb' )
      # mocks/stubs/expected calls
      expect(Ceedling).to receive(:load).with(rakefile_path)
      # execute method
      Ceedling.load_project( config:  './foo.yml',
                             root:    './')
      # validate results
      expect(ENV['CEEDLING_MAIN_PROJECT_FILE']).to eq('./foo.yml')
      expect(PROJECT_ROOT).to eq('./')
    end
  end

  context 'register_plugin' do
    it 'should register a plugin' do
      # create test state/variables
      DEFAULT_CEEDLING_CONFIG[:plugins][:enabled].clear()
      DEFAULT_CEEDLING_CONFIG[:plugins][:load_paths].clear()
      spec_double = double('spec-double')
      # mocks/stubs/expected calls
      expect(Gem::Specification).to receive(:find_by_name).with('ceedling-foo').and_return(spec_double)
      expect(spec_double).to receive(:gem_dir).and_return('dummy/path')
      expect(Ceedling).to receive(:require).with('ceedling/defaults')
      # execute method
      Ceedling.register_plugin('foo')
      # validate results
      expect(DEFAULT_CEEDLING_CONFIG[:plugins][:enabled]).to eq ["foo"]
      expect(DEFAULT_CEEDLING_CONFIG[:plugins][:load_paths]).to eq(["dummy/path"])
    end

    it 'should register a plugin with an alternative prefix' do
      # create test state/variables
      DEFAULT_CEEDLING_CONFIG[:plugins][:enabled].clear()
      DEFAULT_CEEDLING_CONFIG[:plugins][:load_paths].clear()
      spec_double = double('spec-double')
      # mocks/stubs/expected calls
      expect(Gem::Specification).to receive(:find_by_name).with('prefix-foo').and_return(spec_double)
      expect(spec_double).to receive(:gem_dir).and_return('dummy/path')
      expect(Ceedling).to receive(:require).with('ceedling/defaults')
      # execute method
      Ceedling.register_plugin('foo','prefix-')
      # validate results
      expect(DEFAULT_CEEDLING_CONFIG[:plugins][:enabled]).to eq(["foo"])
      expect(DEFAULT_CEEDLING_CONFIG[:plugins][:load_paths]).to eq(["dummy/path"])
    end
  end
end

