require 'spec_helper'
require 'ceedling'

describe 'Ceedling' do
  context 'location' do
    it 'should return the location of the ceedling gem directory' do
      # create test state/variables
      ceedling_path = File.expand_path( File.join( File.dirname(__FILE__), '..' ).gsub( 'spec','lib' ) )
      # mocks/stubs/expected calls
      # execute method
      location = Ceedling.location
      # validate results
      expect(location).to eq(ceedling_path)
    end
  end

  context 'plugins_load_path' do
    it 'should return the location of the plugins directory' do
      # create test state/variables
      load_path = File.expand_path( File.join( File.dirname(__FILE__), '..' ).gsub( 'spec','lib' ) )
      load_path = File.join( load_path, 'plugins' )
      # mocks/stubs/expected calls
      # execute method
      location = Ceedling.plugins_load_path
      # validate results
      expect(location).to eq(load_path)
    end
  end

  context 'rakefile' do
    it 'should return the location of the ceedling rakefile' do
      # create test state/variables
      rakefile_path = File.expand_path( File.join( File.dirname(__FILE__), '..' ).gsub( 'spec','lib' ) )
      rakefile_path = File.join( rakefile_path, 'lib', 'ceedling', 'rakefile.rb' )
      # mocks/stubs/expected calls
      # execute method
      location = Ceedling.rakefile
      # validate results
      expect(location).to eq(rakefile_path)
    end
  end
end

