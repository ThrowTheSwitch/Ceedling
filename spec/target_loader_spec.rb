require 'spec_helper'
require 'ceedling/target_loader'


describe TargetLoader do
  describe '.inspect' do

    it 'raises NoTargets if targets does not exist' do
      expect{TargetLoader.inspect({})}.to raise_error(TargetLoader::NoTargets)
    end

    it 'raises NoDirectory if targets_directory inside of targets does not exist' do
      expect{TargetLoader.inspect({:targets => {}})}.to raise_error(TargetLoader::NoDirectory)
    end

    it 'raises NoDefault if default_target inside of targets does not exist' do
      expect{TargetLoader.inspect({:targets => {:targets_directory => File.join('spec', 'support')}})}.to raise_error(TargetLoader::NoDefault)
    end

    it 'raises NoSuchTarget if file does not exist' do
      expect{TargetLoader.inspect({:targets => {:targets_directory => File.join('spec', 'other'), :default_target => 'target'}})}.to raise_error(TargetLoader::NoSuchTarget)
    end

    it 'raises RequestReload if file exists' do
      expect{TargetLoader.inspect({:targets => {:targets_directory => File.join('spec', 'support'), :default_target => 'target'}})}.to raise_error(TargetLoader::RequestReload)
      expect{TargetLoader.inspect({:targets => {:targets_directory => File.join('spec', 'support'), :default_target => 'target'}}, 'other_target')}.to raise_error(TargetLoader::RequestReload)
    end

  end
end
