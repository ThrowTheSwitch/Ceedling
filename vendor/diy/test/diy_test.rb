require File.dirname(__FILE__) + "/test_helper"
require 'diy'
require 'fileutils'
include FileUtils

class DIYTest < Test::Unit::TestCase

  def setup
    # Add load paths:
    %w|gnu dog cat yak donkey goat horse fud non_singleton namespace functions|.each do |p|
      libdir = path_to_test_file(p)
      $: << libdir unless $:.member?(libdir)
    end
    DIY::Context.auto_require = true # Restore default
  end


  #
  # TESTS
  #

  def test_essential_use_case
    load_context "dog/simple.yml"

    # Check object defs
    check_dog_objects @diy

    # Tweak the load-path
    $: << path_to_test_file("dog")

    # Get the objects, use reference comparison to check composition
    presenter = @diy.get_object('dog_presenter')
    assert_not_nil presenter, 'nil dog_presenter'

    model = @diy.get_object('dog_model') 
    assert_not_nil model, 'nil dog_model'
    assert_same presenter.model, model, "Different model came from context than found in presenter"

    view = @diy.get_object('dog_view') 
    assert_not_nil view, 'nil dog_view'
    assert_same presenter.view, view, "Different view came from context than found in presenter"

    resolver = @diy.get_object('file_resolver')
    assert_not_nil resolver, 'nil file_resolver'
    assert_same model.file_resolver, resolver, "File resolver in model is different than one in context"

    # Check repeat access:
    assert_same model, @diy.get_object('dog_model'), "Second access of model yielded different result"
    assert_same view, @diy.get_object('dog_view'), "Second access of view yielded different result"
    assert_same presenter, @diy.get_object('dog_presenter'), "Second access of presenter got difrnt result"
  end

  def test_classname_inside_a_module
    load_hash 'thinger' => {'class' => "DiyTesting::Bar::Foo", 'lib' => 'foo'}
    @diy.build_everything
    assert_not_nil @diy['thinger'], "Should have got my thinger (which is hiding in a couple modules)"
  end

  def test_classname_inside_a_module_loads_from_directories_named_after_the_underscored_module_names
    load_hash 'thinger' => {'class' => "Foo::Bar::Qux"}
    # expect it to be loaded from: foo/bar/qux.rb
    @diy.build_everything
    assert_not_nil @diy['thinger'], "Should have got my thinger (which is hiding in a couple modules)"
  end

  def test_use_class_directly
    load_hash 'thinger' => {'class' => "DiyTesting::Bar::Foo", 'lib' => 'foo', 'use_class_directly' => true}
    @diy.build_everything
    assert_equal DiyTesting::Bar::Foo, @diy['thinger'], "Should be the class 'object'"
  end

  def test_classname_inside_a_module_derives_the_namespaced_classname_from_the_underscored_object_def_key
    load_hash 'foo/bar/qux' => nil
    @diy.build_everything
    assert_not_nil @diy['foo/bar/qux'], "Should have got my qux (which is hiding in a couple modules)"
  end
    
  def test_keys
    load_context "dog/simple.yml"
    assert_equal %w|dog_model dog_presenter dog_view file_resolver other_thing|, @diy.keys.sort
  end

  def test_subcontext_keys_should_include_parent_context_keys
    load_context 'yak/sub_sub_context_test.yml'
    main_keys = %w|core_presenter core_model core_view data_source|.sort
    assert_equal main_keys, @diy.keys.sort, "Wrong keys in main context"
    @diy.within :fringe_context do |fcontext|
      fringe_keys = [main_keys, %w|fringe_model fringe_view fringe_presenter|].flatten.sort
      assert_equal fringe_keys, fcontext.keys.sort, "Wrong keys in fringe context"
      fcontext.within :deep_context do |dcontext|
        deep_keys = [fringe_keys, %w|krill giant_squid|].flatten.sort
        assert_equal deep_keys, dcontext.keys.sort
      end
    end
  end

  def test_constructor_no_hash
    assert_raise RuntimeError do DIY::Context.new(nil) end
  end

  def test_constructor_bad_extra_inputs
    err = assert_raise RuntimeError  do
      DIY::Context.new({}, Object.new)
    end
    assert_match(/extra inputs/i, err.message)
  end

  def test_from_yaml
    text = File.read(path_to_test_file("dog/simple.yml"))
    diy = DIY::Context.from_yaml(text)
    check_dog_objects diy
  end

  def test_from_yaml_extra_inputs
    extra = { 'the_cat_lineage' => 'siamese', :some_meat => 'horse' }
    diy = DIY::Context.from_yaml(File.read(path_to_test_file('cat/needs_input.yml')), extra)
    cat = diy['cat']
    assert_equal 'siamese', cat.heritage
    assert_equal 'horse', cat.food
  end

  def test_from_file
    diy = DIY::Context.from_file(path_to_test_file("dog/simple.yml"))
    check_dog_objects diy
  end

  def test_from_file_bad
    assert_raise RuntimeError do
      DIY::Context.from_file(nil)
    end
    assert_raise Errno::ENOENT  do
      DIY::Context.from_file("bad file name")
    end
  end

  def test_from_file_extra_inputs
    extra = { 'the_cat_lineage' => 'siamese', :some_meat => 'horse' }
    diy = DIY::Context.from_file(path_to_test_file('cat/needs_input.yml'), extra)
    cat = diy['cat']
    assert_equal 'siamese', cat.heritage
    assert_equal 'horse', cat.food
  end

  def test_contains_object
    load_context "dog/simple.yml"
    assert @diy.contains_object('dog_presenter'), "Should be true for dog_presenter"
    assert !@diy.contains_object('woops'), "Should return false for 'woops'"
    err = assert_raise ArgumentError do
      @diy.contains_object(nil)
    end
  end

  def test_contains_object_extra_inputs
    extra = { 'the_cat_lineage' => 'siamese', :some_meat => 'horse' }
    main = YAML.load(File.read(path_to_test_file('cat/needs_input.yml')))
    diy = DIY::Context.new(main, extra)

    assert diy.contains_object('cat')
    assert diy.contains_object('the_cat_lineage')
    assert diy.contains_object('some_meat')
  end

  def test_get_object
    load_context "dog/simple.yml"
    assert_not_nil @diy.get_object('file_resolver'), "nil resolver?"
    assert_raise ArgumentError do
      @diy.get_object(nil)
    end
    assert_raise DIY::ConstructionError do
      @diy.get_object("no such object")
    end
  end

  def test_hash_style_access
    load_context "dog/simple.yml"
    assert_not_nil @diy['file_resolver'], "nil resolver?"
    assert_raise ArgumentError do
      @diy[nil]
    end
    assert_raise DIY::ConstructionError do
      @diy["no such object"]
    end
  end

  def test_get_object_construction_error
    load_context "broken_construction.yml"
    err = assert_raise DIY::ConstructionError  do
      @diy.get_object 'dog_presenter'
    end
    assert_match(/dog_presenter/, err.message)  
  end

  def test_context_with_extra_inputs
    extra = { 'the_cat_lineage' => 'siamese', :some_meat => 'horse' }
    main = YAML.load(File.read(path_to_test_file('cat/needs_input.yml')))
    diy = DIY::Context.new(main, extra)
    cat = diy['cat']
    assert_equal 'siamese', cat.heritage
    assert_equal 'horse', cat.food
  end

  def test_conflicting_extra_inputs
    extra = { 'the_cat_lineage' => 'siamese', :some_meat => 'horse' }
    main = YAML.load(File.read(path_to_test_file('cat/extra_conflict.yml')))

    DIY::Context.new(main,extra)
    flunk "Should have raised err"
  rescue Exception => err
    assert_match(/conflict/i, err.message)
  end

  def test_sub_context
    load_context 'yak/my_objects.yml'

    core_model = @diy['core_model']
    assert_not_nil core_model, "no core model in main context?"

    fmodel1 = nil
    fview1 = nil
    @diy.within('fringe_context') do |fc|
      assert_not_nil fc["fringe_presenter"], "no fringe presenter"
      fmodel1 = fc["fringe_model"]
      fmodel1a = fc["fringe_model"]
      assert_same fmodel1, fmodel1a, "Second fring model in fringe_context came out different"
      assert_not_nil fmodel1, "no fringe_model"
      fview1 = fc["fringe_view"]
      assert_not_nil fview1, "no fringe_view"
      assert_same  core_model, fmodel1.connected
    end

    fmodel2 = nil
    fview2 = nil
    @diy.within('fringe_context') do |fc|
      assert_not_nil fc["fringe_presenter"], "2: no fringe presenter"
      fmodel2 = fc["fringe_model"]
      fmodel2a = fc["fringe_model"]
      assert_same fmodel2, fmodel2a, "Second fringe model in fringe_context came out different"
      assert_not_nil fmodel2, "2: no fringe_model"
      fview2 = fc["fringe_view"]
      assert_not_nil fview2, "2: no fringe_view"
      assert_same  core_model, fmodel2.connected

      assert fmodel1.object_id != fmodel2.object_id, "fringe models 1 and 2 are same!"
      assert fview1.object_id != fview2.object_id, "fringe views 1 and 2 are same!"
    end
  end

  def test_sub_sub_context
    load_context 'yak/sub_sub_context_test.yml'

    core_model = @diy['core_model']
    assert_not_nil core_model, "no core model in main context?"

    fmodel1 = nil
    fview1 = nil
    @diy.within('fringe_context') do |fc|
      assert_not_nil fc["fringe_presenter"], "no fringe presenter"
      fmodel1 = fc["fringe_model"]
      fmodel1a = fc["fringe_model"]
      assert_same fmodel1, fmodel1a, "Second fring model in fringe_context came out different"
      assert_not_nil fmodel1, "no fringe_model"
      fview1 = fc["fringe_view"]
      assert_not_nil fview1, "no fringe_view"
      assert_same  core_model, fmodel1.connected

      fc.within :deep_context do |dc|
        krill = dc['krill']
        assert_not_nil krill, "nil krill"
        assert_same krill, dc['krill'], "krill was different second time"
        giant_squid = dc['giant_squid']
        assert_same fview1, giant_squid.fringe_view, "wrong view in squid"
        assert_same core_model, giant_squid.core_model, "wrong model in squid"
        assert_same krill, giant_squid.krill, "wrong krill in squid"
      end
    end

  end

  def test_build_everything
    # Singletons in the goat context will generate test output in their constructors.
    # We just gotta tell em where:
    ofile = path_to_test_file('goat/output.tmp')
    $goat_test_output_file = ofile

    # Reusable setup for this test
    prep_output = proc do 
    remove ofile if File.exist?(ofile)
  end

  # Reusable assertion set and cleanup
  examine_output = proc do
    # Examine output file for expected construction
    assert File.exist?(ofile), "no goat output created"
    lines = File.readlines(ofile).map { |x| x.strip }
    %w|can paper shirt goat|.each do |object|
      assert lines.member?("#{object} built"), "Didn't see constructor output for #{object}"
    end
    assert_equal 4, lines.size, "wrong number of entries in output file"

    # Make sure the subcontext was not built
    assert !lines.member?("plane built"), "plane should not have been built -- it's in the subcontext"
    assert !lines.member?("wings built"), "wings should not have been built -- it's in the subcontext"

    # Check the objects in the context
    %w|can paper shirt goat|.each do |object|
      assert_same @diy[object], @diy[object], "Multiple accesses on #{object} yielded different refs"
    end

    # Try the subcontext
    @diy.within('the_sub_context') do |tsc|
      %w|plane wings|.each do |object|
        assert_same tsc[object], tsc[object], "Multiple accesses on #{object} (in subcontext) yielded different refs"
      end
    end
    # cleanup
    remove ofile if File.exist?(ofile)
  end

  # Test all three methods
  [:build_everything, :build_all, :preinstantiate_singletons].each do |method_name|
    prep_output.call
    load_context 'goat/objects.yml'
    # go
    @diy.send method_name
    examine_output.call
  end
  ensure
    # cleanup
    remove ofile if File.exist?(ofile)
  end

  # See that the current object factory context can be referenced within the yaml
  def test_this_context
    load_context 'horse/objects.yml'

    assert_same @diy, @diy['this_context'], "basic self-reference failed"
    assert_same @diy, @diy['holder_thing'].thing_held, "composition self-reference failed"
  end

  def test_this_context_works_for_subcontexts
    load_context 'horse/objects.yml'

    @diy.within('repeater') do |ctx|
      assert_same ctx, ctx['this_context'], "self-ref inside a subcontext doesn't work"
    end
  end

  def test_multiple_classes_in_one_file
    load_context 'fud/objects.yml'

    toy = @diy['toy']
    widget = @diy['widget']
    thing = @diy['thing_ama_jack']
    trinket = @diy['trinket']

    assert_same widget, toy.widget, "wrong widget in toy"
    assert_same trinket, toy.trinket, "wrong trinket in toy"
    assert_same thing, trinket.thing_ama_jack, "wrong thing_ama_jack in trinket"
  end

  def test_objects_can_be_set_in_a_context_and_diy_will_not_attempt_to_build_it_as_a_dependency
    load_context 'gnu/objects.yml'

    injected = 'boom'
    @diy[:injected] = injected
    thinger = @diy[:thinger]
    assert_not_nil thinger
    assert_same injected, thinger.injected
    assert_same injected, @diy[:injected]

    inner_injected = 'slam'
    @diy.within :inny  do |sub|
      sub.set_object :inner_injected, inner_injected
      inner_thinger = sub[:inner_thinger]
      assert_not_nil inner_thinger
      assert_same inner_injected, inner_thinger.injected
      assert_same inner_injected, sub[:inner_injected]
    end
  end

	def test_should_not_allow_setting_of_an_object_which_has_already_been_loaded
    load_context 'gnu/objects.yml'

    injected = 'boom'
    @diy[:injected] = injected
		err = assert_raise RuntimeError do
			@diy[:injected] = injected
		end
		assert_match(/object 'injected' already exists/i, err.message)
		assert_same injected, @diy[:injected]

		thinger = @diy[:thinger]
		err = assert_raise RuntimeError do
			@diy[:thinger] = 'sdf'
		end
		assert_match(/object 'thinger' already exists/i, err.message)
		assert_same thinger, @diy[:thinger]
	end

	def test_should_be_able_to_turn_off_auto_require_for_all_objects
	  DIY::Context.auto_require = false
	  load_context 'horse/objects.yml'
	  
	  exception = assert_raise(DIY::ConstructionError) { @diy['holder_thing'] }
	  assert_match(/uninitialized constant/, exception.message)
  end

  def test_should_cause_non_singletons_to_be_rebuilt_every_time_they_are_accessed
    load_context 'non_singleton/objects.yml'

    air = @diy['air']
    assert_not_nil air, "No air"
    assert_same air, @diy['air'], "Air should be a singleton"

    yard = @diy['yard']
    assert_not_nil yard, "No yard"
    assert_same yard, @diy['yard'], "yard should be a singleton"

    pig = @diy['pig']
    assert_not_nil pig, "No pig"
    assert_same pig, @diy['pig'], "Pig should be a singleton"

    thread_spinner1 = @diy['thread_spinner']
    assert_not_nil thread_spinner1, "Couldn't get thread spinner"
    thread_spinner2 = @diy['thread_spinner']
    assert_not_nil thread_spinner2, "Couldn't get second thread spinner"
    assert thread_spinner1.object_id != thread_spinner2.object_id, "Thread spinners should be different instances"
    thread_spinner3 = pig.thread_spinner
    assert_not_nil thread_spinner3, "Didn't get a spinner from the pig"
    assert thread_spinner2.object_id != thread_spinner3.object_id, "Thread spinner from pig should be different instance than the others"
    assert thread_spinner1.object_id != thread_spinner3.object_id, "Thread spinner from pig should be different instance than the others"

    assert_same air, thread_spinner1.air, "spinner 1 air should be singleton reference"
    assert_same air, thread_spinner2.air, "spinner 2 air should be singleton reference"
    assert_same air, thread_spinner3.air, "spinner 3 air should be singleton reference"
  end

  def test_should_handle_nonsingletons_in_sub_contexts
    load_context 'non_singleton/objects.yml'

    yard = @diy['yard']
    assert_not_nil yard, "No yard"
    assert_same yard, @diy['yard'], "yard should be a singleton"

    thread_spinner1 = @diy['thread_spinner']
    assert_not_nil thread_spinner1, "Couldn't get thread spinner"

    air = @diy['air']
    assert_not_nil air, "No air"
    assert_same air, @diy['air'], "Air should be a singleton"

    @diy.within :inner_sanctum do |sanct|
      tick1 = sanct['tick']
      assert_not_nil tick1, "Couldn't get tick1 from inner sanctum"
      tick2 = sanct['tick']
      assert_not_nil tick2, "Couldn't get tick2 from inner sanctum"
      assert tick1.object_id != tick2.object_id, "Tick should not be a singleton"

      cat = sanct['fat_cat']
      assert_not_nil cat, "Couldn't get cat from sanctum"
      assert_same cat, sanct['fat_cat'], "Cat SHOULD be singleton"

      tick3 = cat.tick
      assert_not_nil  tick3, "Couldn't get tick from cat"
      assert tick1.object_id != tick3.object_id, "tick from cat matched an earlier tick; should not be so"
      
      assert_same yard, cat.yard, "Cat's yard should be same as other yard"
      assert_not_nil cat.thread_spinner, "No thread spinner in cat?"

      assert_same air, cat.thread_spinner.air, "spinner 1 air should be singleton reference"
      assert thread_spinner1.object_id != cat.thread_spinner.object_id, "cat's thread spinner matched the other spinner; should not be so"
    end
  end
  
  def test_should_provide_syntax_for_using_namespace
    # This test exercises single and triple-level namespaces for nested
    # modules, and their interaction with other namespaced-objects.
    load_context "namespace/objects.yml"

    %w{road sky cat bird lizard turtle}.each do |obj|
      assert @diy.contains_object(obj), "Context had no object '#{obj}'"
    end

    road = @diy['road']
    sky = @diy['sky']
    cat = @diy['cat']
    bird = @diy['bird']
    lizard = @diy['lizard']
    turtle = @diy['turtle']

    assert_same road, cat.road, "Cat has wrong Road"
    assert_same sky, bird.sky, "Bird has wrong Sky"
    assert_same bird, lizard.bird, "Lizard has wrong Bird"
  end
  
  def test_should_combine_a_given_class_name_with_the_namespace
    load_context "namespace/class_name_combine.yml"
    assert_not_nil @diy['garfield'], "No garfield"
    assert_kind_of Animal::Cat, @diy['garfield'], "Garfield wrong"
  end

  def test_should_let_you_use_namespaces_in_subcontexts
    load_context "namespace/subcontext.yml"
    @diy.build_everything
    %w{road sky cat turtle}.each do |obj|
      assert @diy.contains_object(obj), "Main context had no object '#{obj}'"
    end
    sky = @diy['sky']

    @diy.within("aviary") do |subc|
      assert subc.contains_object("bird"), "Sub context didn't have 'bird'"
      assert subc.contains_object("lizard"), "Sub context didn't have 'lizard'"
      bird = subc['bird']
      lizard = subc['lizard']
      assert_same sky, bird.sky, "Bird has wrong Sky"
      assert_same bird, lizard.bird, "Lizard has wrong Bird"
    end
  end

  def test_should_raise_for_namespace_w_no_modules_named
    ex = assert_raises DIY::NamespaceError do
      load_context "namespace/no_module_specified.yml"
    end
    assert_equal "Namespace needs to indicate a module", ex.message
  end

  def test_should_raise_for_namespace_whose_modules_dont_exist
    load_context "namespace/bad_module_specified.yml"
    ex = assert_raises DIY::ConstructionError do
      @diy['bird']
    end
    assert_match(/failed to construct/i, ex.message)
    assert_match(/no such file to load -- fuzzy_creature\/bird/, ex.message)
  end

  def test_should_be_able_define_and_access_bounded_methods
    load_context "functions/objects.yml"
    @diy.build_everything
    build_thing = @diy['build_thing']
    
    assert_not_nil build_thing, "should not be nil"
    assert_kind_of(Method, build_thing)
    assert_equal(build_thing, @diy['build_thing'])
  end
  
  def test_bounded_method_can_be_used
    load_context "functions/objects.yml"
    @diy.build_everything
    build_thing = @diy['build_thing']
    
    thing = build_thing["the name", "flying"]
    
    assert_equal("the name", thing.name)
    assert_equal("flying", thing.ability)
  end
  
  def test_building_bounded_method_uses_object_in_diy_context_correctly
    load_context "functions/objects.yml"
    @diy.build_everything
    assert_equal(@diy['build_thing'], @diy['thing_builder'].method(:build))
    
    load_context "functions/nonsingleton_objects.yml"
    @diy.build_everything
    assert_not_equal(@diy['build_thing'], @diy['thing_builder'].method(:build))
  end
  
  def test_composing_bounded_methods_into_other_objects
    load_context "functions/objects.yml"
    @diy.build_everything
    assert_equal(@diy['build_thing'], @diy['things_builder'].build_thing)
  end
  
  def test_raises_construction_error_if_invalid_method_specified
    load_context "functions/invalid_method.yml"
    assert_raises DIY::ConstructionError do
      @diy.build_everything
    end
  end
  
  def test_can_optionally_attach_method_to_other_objects_in_context
    load_context "functions/objects.yml"
    @diy.build_everything
    
    thing = @diy['attached_things_builder'].build_thing("the name", "flying")
    assert_kind_of(Thing, thing)
    assert_equal("the name", thing.name)
    assert_equal("flying", thing.ability)    
    
    ["attached_things_builder", "things_builder"].each do |key|
      thing = @diy[key].build_default_thing
      assert_kind_of(Thing, thing)
      assert_equal("Thing", thing.name)
      assert_equal("nothing", thing.ability)    
    end
  end
  
  #
  # HELPERS
  #
  def check_dog_objects(context)
    assert_not_nil context, "nil context"
    names = %w|dog_presenter dog_model dog_view file_resolver|
    names.each do |n|
      assert context.contains_object(n), "Context had no object '#{n}'"
    end
  end

end
