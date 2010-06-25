require File.dirname(__FILE__) + '/../unit_test_helper'
require 'file_path_utils'


class FilePathUtilsTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator, :file_wrapper)
    @utils = FilePathUtils.new(objects)
  end

  def teardown
  end


  should "standardize paths with forward slash file separators and prepend with ./" do
    assert_equal('files/dir/dir',       FilePathUtils::standardize("files\\dir\\dir/"))
    assert_equal('root/subdir/dir',     FilePathUtils::standardize("root\\subdir\\dir\\"))
    assert_equal('files/modules/tests', FilePathUtils::standardize("files/modules/tests"))
    assert_equal('source/modules',      FilePathUtils::standardize("source\\modules"))
    assert_equal('source/modules',      FilePathUtils::standardize("./source\\modules"))
    assert_equal('source/modules',      FilePathUtils::standardize(".\\source\\modules"))
    assert_equal('',                    FilePathUtils::standardize("./"))
    assert_equal('.',                   FilePathUtils::standardize("."))
  end


  should "find base directory up to glob notation or filename" do    
    assert_equal('/files/stuff',  FilePathUtils::dirname('/files/stuff/'))
    assert_equal('/files/stuff',  FilePathUtils::dirname('/files/stuff'))
    assert_equal('.',             FilePathUtils::dirname('.'))

    assert_equal('.',             FilePathUtils::dirname('./*'))
    assert_equal('/files/stuff',  FilePathUtils::dirname('/files/stuff/**'))
    assert_equal('/files/stuff',  FilePathUtils::dirname('/files/stuff/*'))
    assert_equal('/files/stuff',  FilePathUtils::dirname('/files/stuff/**/more*'))
    assert_equal('files/tests',   FilePathUtils::dirname('files/tests/*test/**/thing*/**'))
    assert_equal('files',         FilePathUtils::dirname('files/test*'))

    assert_equal('files/tests',   FilePathUtils::dirname('files/tests/???src'))
    assert_equal('project/files', FilePathUtils::dirname('project/files/test?'))

    assert_equal('project/files', FilePathUtils::dirname('project/files/test[123]'))

    assert_equal('project/files', FilePathUtils::dirname('project/files/test{ing,s}'))

    assert_equal('project/files', FilePathUtils::dirname('project/files/**/**'))
  end


  should "form valid subdirectory recursing globs from path convention" do
    assert_equal('/files/stuff/', FilePathUtils::reform_glob('/files/stuff/'))
    assert_equal('/files/stuff',  FilePathUtils::reform_glob('/files/stuff'))
    assert_equal('.',             FilePathUtils::reform_glob('.'))

    assert_equal('./*',                               FilePathUtils::reform_glob('./*'))
    assert_equal('/files/stuff/**/**',                FilePathUtils::reform_glob('/files/stuff/**'))
    assert_equal('/files/stuff/*',                    FilePathUtils::reform_glob('/files/stuff/*'))
    assert_equal('/files/stuff/**/more*',             FilePathUtils::reform_glob('/files/stuff/**/more*'))
    assert_equal('files/tests/*test/**/thing*/**/**', FilePathUtils::reform_glob('files/tests/*test/**/thing*/**'))

    assert_equal('files/tests/???src',  FilePathUtils::reform_glob('files/tests/???src'))
    assert_equal('project/files/test?', FilePathUtils::reform_glob('project/files/test?'))

    assert_equal('project/files/test[123]', FilePathUtils::reform_glob('project/files/test[123]'))

    assert_equal('project/files/test{ing,s}', FilePathUtils::reform_glob('project/files/test{ing,s}'))
  end


  should "form runner object file path from configuration and file name" do
    @configurator.expects.project_test_build_output_path.returns('project/build/output')
    @configurator.expects.extension_object.returns('.obj')
    @configurator.expects.extension_object.returns('.obj')
    @configurator.expects.test_runner_file_suffix.returns('_runner')
    
    assert_equal('project/build/output/test_stuff_runner.obj', @utils.form_runner_object_filepath_from_test('files/junk/test_stuff.c'))
  end


  should "form runner object file path from configuration and file name" do
    @configurator.expects.project_test_build_output_path.returns('project/build/output')
    @configurator.expects.extension_object.returns('.o')
    
    assert_equal('project/build/output/stuff.o', @utils.form_object_filepath('files/junk/stuff.c'))
  end


  should "form executable file path from configuration and file name" do
    @configurator.expects.project_test_build_output_path.returns('project/build/output')
    @configurator.expects.extension_executable.returns('.out')
    
    assert_equal('project/build/output/test_stuff.out', @utils.form_executable_filepath('files/tests/test_stuff.c'))
  end

end

