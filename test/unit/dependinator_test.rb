require File.dirname(__FILE__) + '/../unit_test_helper'
require 'dependinator'


class DependinatorTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator, :test_includes_extractor, :file_finder, :file_path_utils, :rake_wrapper)
    @dependinator = Dependinator.new(objects)

    create_mocks(:headers1, :headers2, :sources1, :sources2, :dependencies1, :dependencies2)
    create_mocks(:files_list1, :files_list2)
  end

  def teardown
  end


  should "set up no object dependencies for empty files lists" do
    @dependinator.setup_test_object_dependencies
  end


  should "set up object dependencies for files lists" do
    @file_path_utils.expects.form_dependencies_filelist(@files_list1).returns(['projects/build/dependencies/MockIngBird.d', 'projects/build/dependencies/MockAndRoll.d'])
    @rake_wrapper.expects.load_dependencies('projects/build/dependencies/MockIngBird.d')
    @rake_wrapper.expects.load_dependencies('projects/build/dependencies/MockAndRoll.d')

    @file_path_utils.expects.form_dependencies_filelist(@files_list2).returns(['projects/build/dependencies/MockAroundTheClock.d', 'projects/build/dependencies/MockHimOut.d'])
    @rake_wrapper.expects.load_dependencies('projects/build/dependencies/MockAroundTheClock.d')
    @rake_wrapper.expects.load_dependencies('projects/build/dependencies/MockHimOut.d')
    
    @dependinator.setup_test_object_dependencies(@files_list1, @files_list2)
  end


  should "set up no executable dependencies for blank test list" do
    @dependinator.setup_test_executable_dependencies([])
  end


  should "set up executable dependencies for a test list with CException" do
    test_list = ['test1.c', 'test2.c']

    @test_includes_extractor.expects.lookup_includes_list(test_list[0]).returns(@headers1)
    @file_finder.expects.find_source_files_from_headers(@headers1).returns(@sources1)

    @file_path_utils.expects.form_source_objects_filelist(@sources1).returns(@dependencies1)
    
    @file_path_utils.expects.form_runner_object_filepath_from_test(test_list[0]).returns('/project/build/out/test1_runner.c')
    @dependencies1.expects.include('/project/build/out/test1_runner.c')
    @file_path_utils.expects.form_object_filepath(test_list[0]).returns('project/build/out/test1.o')
    @dependencies1.expects.include('project/build/out/test1.o')
    @configurator.expects.project_use_exceptions.returns(true)
    @file_path_utils.expects.form_object_filepath('CException.c').returns('project/build/out/CException.o')
    @dependencies1.expects.include('project/build/out/CException.o')

    @dependencies1.expects.uniq!
    
    @file_path_utils.expects.form_executable_filepath(test_list[0]).returns('project/build/out/test1.exe')
    @rake_wrapper.expects.create_file_task('project/build/out/test1.exe', @dependencies1)


    @test_includes_extractor.expects.lookup_includes_list(test_list[1]).returns(@headers2)
    @file_finder.expects.find_source_files_from_headers(@headers2).returns(@sources2)

    @file_path_utils.expects.form_source_objects_filelist(@sources2).returns(@dependencies2)
    
    @file_path_utils.expects.form_runner_object_filepath_from_test(test_list[1]).returns('/project/build/out/test2_runner.c')
    @dependencies2.expects.include('/project/build/out/test2_runner.c')
    @file_path_utils.expects.form_object_filepath(test_list[1]).returns('project/build/out/test2.o')
    @dependencies2.expects.include('project/build/out/test2.o')
    @configurator.expects.project_use_exceptions.returns(true)
    @file_path_utils.expects.form_object_filepath('CException.c').returns('project/build/out/CException.o')
    @dependencies2.expects.include('project/build/out/CException.o')

    @dependencies2.expects.uniq!
    
    @file_path_utils.expects.form_executable_filepath(test_list[1]).returns('project/build/out/test2.exe')
    @rake_wrapper.expects.create_file_task('project/build/out/test2.exe', @dependencies2)

    
    @dependinator.setup_test_executable_dependencies(test_list)
  end


  should "set up executable dependencies for a test list without CException" do
    test_list = ['testing1.c', 'testing2.c']

    @test_includes_extractor.expects.lookup_includes_list(test_list[0]).returns(@headers1)
    @file_finder.expects.find_source_files_from_headers(@headers1).returns(@sources1)

    @file_path_utils.expects.form_source_objects_filelist(@sources1).returns(@dependencies1)
    
    @file_path_utils.expects.form_runner_object_filepath_from_test(test_list[0]).returns('/project/build/out/testing1_runner.c')
    @dependencies1.expects.include('/project/build/out/testing1_runner.c')
    @file_path_utils.expects.form_object_filepath(test_list[0]).returns('project/build/out/testing1.o')
    @dependencies1.expects.include('project/build/out/testing1.o')
    @configurator.expects.project_use_exceptions.returns(false)

    @dependencies1.expects.uniq!
    
    @file_path_utils.expects.form_executable_filepath(test_list[0]).returns('project/build/out/testing1.exe')
    @rake_wrapper.expects.create_file_task('project/build/out/testing1.exe', @dependencies1)


    @test_includes_extractor.expects.lookup_includes_list(test_list[1]).returns(@headers2)
    @file_finder.expects.find_source_files_from_headers(@headers2).returns(@sources2)

    @file_path_utils.expects.form_source_objects_filelist(@sources2).returns(@dependencies2)
    
    @file_path_utils.expects.form_runner_object_filepath_from_test(test_list[1]).returns('/project/build/out/testing2_runner.c')
    @dependencies2.expects.include('/project/build/out/testing2_runner.c')
    @file_path_utils.expects.form_object_filepath(test_list[1]).returns('project/build/out/testing2.o')
    @dependencies2.expects.include('project/build/out/testing2.o')
    @configurator.expects.project_use_exceptions.returns(false)

    @dependencies2.expects.uniq!
    
    @file_path_utils.expects.form_executable_filepath(test_list[1]).returns('project/build/out/testing2.exe')
    @rake_wrapper.expects.create_file_task('project/build/out/testing2.exe', @dependencies2)

    
    @dependinator.setup_test_executable_dependencies(test_list)
  end


end

