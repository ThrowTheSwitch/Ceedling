# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

directory(CPPCHECK_BUILD_PATH)
directory(CPPCHECK_ARTIFACTS_PATH)

CLEAN.include(File.join(CPPCHECK_BUILD_PATH, '*'))
CLEAN.include(File.join(CPPCHECK_ARTIFACTS_PATH, '*'))

CLOBBER.include(File.join(CPPCHECK_BUILD_PATH, '**/*'))

task :cppcheck_deps => [:directories, CPPCHECK_BUILD_PATH, CPPCHECK_ARTIFACTS_PATH]
task :cppcheck => ['cppcheck:all']

namespace :cppcheck do
  desc "Run whole project analysis (also just 'cppcheck' works)."
  task :all => [:cppcheck_deps] do
    @ceedling[CPPCHECK_SYM].generate_reports()
  end
  
  desc "Run single file analysis ([*] source file name, no path)."
  task :* do
    message = "Oops! '#{CPPCHECK_ROOT_NAME}:*' isn't a real task. " +
              "Use a real source file name (no path) in place of the wildcard.\n" +
              "Example: `ceedling #{CPPCHECK_ROOT_NAME}:foo.c`"

    @ceedling[:loginator].log(message, Verbosity::ERRORS)
  end
end

rule (/^#{CPPCHECK_TASK_ROOT}\S+$/) => [
  proc do |task_name|
    name = task_name.sub(/^#{CPPCHECK_TASK_ROOT}/, '')
    ['cppcheck_deps', @ceedling[:file_finder].find_source_file(name)]
  end
] do |task|
  @ceedling[CPPCHECK_SYM].analyze_file(task.sources[1])
end

namespace :files do
  desc 'List all collected Cppcheck suppression files.'
  task :cppcheck do
    files_list = COLLECTION_ALL_CPPCHECK
    puts "Cppcheck suppression files:#{' None' if files_list.size == 0}"
    if files_list.size > 0
      files_list.sort.each { |filepath| puts " - #{filepath}" }
      puts "File count: #{files_list.size}"
    end
  end
end
