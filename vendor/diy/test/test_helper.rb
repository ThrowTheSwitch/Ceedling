here = File.expand_path(File.dirname(__FILE__))
PROJ_ROOT = File.expand_path("#{here}/..")
$: << "#{PROJ_ROOT}/lib"
require 'test/unit'
require 'fileutils'
require 'find'
require 'yaml'
require 'ostruct'
require "#{here}/constructor"

class Test::Unit::TestCase
	include FileUtils

	def path_to(file)
		File.expand_path(File.dirname(__FILE__)) + file
	end

	def not_done
		flunk "IMPLEMENT ME"
	end
	alias :implement_me :not_done

	def poll(time_limit) 
		(time_limit * 10).to_i.times do 
			return true if yield
			sleep 0.1
		end
		return false
	end

	def self.method_added(msym)
		# Prevent duplicate test methods 
		if msym.to_s =~ /^test_/
			@_tracked_tests ||= {}
			raise "Duplicate test #{msym}" if @_tracked_tests[msym]
			@_tracked_tests[msym] = true
		end
	end

  #
  # HELPERS
  #
  def path_to_test_file(fname)
    path_to("/files/#{fname}")
  end

  def load_context(file_name)
    hash = YAML.load(File.read(path_to_test_file(file_name)))
    load_hash(hash)
  end

  def load_hash(hash)
    @diy = DIY::Context.new(hash)
  end
end
