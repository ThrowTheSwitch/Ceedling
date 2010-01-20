require File.dirname(__FILE__) + "/test_helper"
require 'diy'
require 'fileutils'
include FileUtils

class FactoryTest < Test::Unit::TestCase

  def setup
    # Add load paths:
    %w|factory|.each do |p|
      libdir = path_to_test_file(p)
      $: << libdir unless $:.member?(libdir)
    end
    DIY::Context.auto_require = true # Restore default
  end


  #
  # TESTS
  #

  def test_creates_factory
    load_context "factory/factory.yml"

    cat_factory = @diy.get_object(:cat_factory)
    assert_not_nil cat_factory

    cat = cat_factory.create('a', 'b')

    assert cat.is_a?(Kitten)
    assert_equal "meow", cat.meow
    assert_equal 'a', cat.a
    assert_equal 'b', cat.b
  end

  def test_creates_factory_with_autorequire
    load_context "factory/factory.yml"

    dog_factory = @diy.get_object(:dog_factory)
    assert_not_nil dog_factory

    dog = dog_factory.create

    assert dog.is_a?(Dog)
    assert_equal "woof", dog.woof
  end

  def test_creates_factory_with_subcontext
    load_context "factory/factory.yml"

    @diy.within :inny do |context|
      bull_factory = context.get_object(:bull_factory)
      beef = bull_factory.create
    end
  end

  def test_creates_factory_with_subcontext_and_namespace
    load_context "factory/factory.yml"

    @diy.within :congress do |context|
      politician = context.get_object(:politician)
      pork = politician.create
      assert pork.is_a?(Farm::Pork)
      assert_equal "money!", pork.oink
    end
  end

  def test_creates_factory_with_namespace
    load_context "factory/factory.yml"

    llama_factory = @diy.get_object(:llama_factory)
    assert_not_nil llama_factory

    llama = llama_factory.create

    assert llama.is_a?(Farm::Llama)
    assert_equal "?", llama.make_llama_noise
  end
end
