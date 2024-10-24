# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class Dependinator

  constructor :configurator, :test_context_extractor, :file_path_utils, :rake_wrapper, :file_wrapper


  def load_release_object_deep_dependencies(dependencies_list)
    dependencies_list.each do |dependencies_file|
      if File.exist?(dependencies_file)
        @rake_wrapper.load_dependencies( dependencies_file )
      end
    end
  end


  def load_test_object_deep_dependencies(files_list)
    dependencies_list = @file_path_utils.form_test_dependencies_filelist(files_list)
    dependencies_list.each do |dependencies_file|
      if File.exist?(dependencies_file)
        @rake_wrapper.load_dependencies(dependencies_file)
      end
    end
  end

end
