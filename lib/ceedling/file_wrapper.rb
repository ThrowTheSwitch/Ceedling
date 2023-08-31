require 'rubygems'
require 'rake' # for FileList
require 'fileutils'
require 'ceedling/constants'


class FileWrapper

  def get_expanded_path(path)
    return File.expand_path(path)
  end

  def basename(path, extension=nil)
    return File.basename(path, extension) if extension
    return File.basename(path)
  end

  def exist?(filepath)
    return true if (filepath == NULL_FILE_PATH)
    return File.exist?(filepath)
  end

  def extname(filepath)
    return File.extname(filepath)
  end

  def directory?(path)
    return File.directory?(path)
  end

  def dirname(path)
    return File.dirname(path)
  end

  def directory_listing(glob)
    return Dir.glob(glob, File::FNM_PATHNAME)
  end

  def rm_f(filepath, options={})
    FileUtils.rm_f(filepath, **options)
  end

  def rm_r(filepath, options={})
    FileUtils.rm_r(filepath, **options={})
  end

  def rm_rf(path, options={})
    FileUtils.rm_rf(path, **options={})
  end

  def cp(source, destination, options={})
    FileUtils.cp(source, destination, **options)
  end

  def cp_r(source, destination, options={})
    FileUtils.cp_r(source, destination, **options)
  end

  def mv(source, destination, options={})
    FileUtils.mv(source, destination, **options)
  end

  def compare(from, to)
    return FileUtils.compare_file(from, to)
  end

  # Is filepath A newer than B?
  def newer?(filepathA, filepathB)
    return false unless File.exist?(filepathA)
    return false unless File.exist?(filepathB)

    return (File.mtime(filepathA) > File.mtime(filepathB))
  end

  def open(filepath, flags)
    File.open(filepath, flags) do |file|
      yield(file)
    end
  end

  def read(filepath)
    return File.read(filepath)
  end

  def touch(filepath, options={})
    FileUtils.touch(filepath, **options)
  end

  def write(filepath, contents, flags='w')
    File.open(filepath, flags) do |file|
      file.write(contents)
    end
  end

  def readlines(filepath)
    return File.readlines(filepath)
  end

  def instantiate_file_list(files=[])
    return FileList.new(files)
  end

  def mkdir(folder)
    return FileUtils.mkdir_p(folder)
  end

end
