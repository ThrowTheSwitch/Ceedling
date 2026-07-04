# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class RakeTaskRegistry

  # Semantic tag constants — used as keys in the namespace_tags registry
  TAG_TEST    = :test
  TAG_RELEASE = :release
  TAG_BUILD   = :build

  # Composite tag sets — applied as a group when registering a domain
  TAGS_TEST    = [TAG_TEST,    TAG_BUILD].freeze
  TAGS_RELEASE = [TAG_RELEASE, TAG_BUILD].freeze

  # Marker regexes — a line matching any marker signals the enclosing namespace
  # belongs to the associated domain.
  #
  # MARKER_TEST_TASKS_SETUP_AND_INVOKE matches any call of the form:
  #   @ceedling[:test_invoker].setup_and_invoke(
  #
  # MARKER_RELEASE_TASKS matches any call of the form:
  #   @ceedling[:release_invoker].setup_and_invoke_objects(

  MARKER_TEST_TASKS_SETUP_AND_INVOKE = /\[\s*:test_invoker\s*\]\.setup_and_invoke/
  MARKER_TEST_TASKS_RAKE_INVOKE      = /test:.+\.invoke/
  MARKER_RELEASE_TASKS               = /\[\s*:release_invoker\s*\]\.setup_and_invoke_objects/

  def initialize
    # Maps root namespace string → Array<Symbol> of semantic tags
    # e.g. { 'test' => [:test, :build], 'gcov' => [:test, :build], 'release' => [:release, :build] }
    @namespace_tags = {}
  end

  # Returns all tags associated with a task name.
  # Any task form maps to its root namespace:
  #   'test:all'      → root 'test'
  #   'test:foo_file' → root 'test'  (rule-synthesized tasks handled for free)
  #   'test'          → root 'test'  (bare alias handled for free)
  #   'gcov:all'      → root 'gcov'
  def tags_for(task_name)
    root = task_name.split(':').first
    @namespace_tags[root] || []
  end

  # Returns true if the task is associated with the given tag.
  def task_is?(task_name, tag)
    tags_for( task_name ).include?( tag )
  end

  # Returns all registered namespace strings that carry the given tag.
  # Used by RakeInvocationTracker to build dynamic regex patterns for invocation checks.
  def namespaces_for_tag(tag)
    @namespace_tags.select { |_, tags| tags.include?( tag ) }.keys
  end

  # Directly register a namespace string with one or more tags.
  # Merges with any existing tags — does not overwrite prior registrations.
  # Example: register_namespace( 'plugin', *TAGS_TEST )
  def register_namespace(namespace, *tags)
    @namespace_tags[namespace] ||= []
    tags.each do |tag|
      @namespace_tags[namespace] << tag unless @namespace_tags[namespace].include?( tag )
    end
  end

  # Scan .rake files as text to identify Rake namespaces (and lone task aliases)
  # that invoke the test pipeline. Text scanning is used instead of Rake's task
  # inspection API because Rake tasks don't exist as objects until their .rake
  # files are loaded — but we need namespace identification before that, so
  # bin/ CLI code can determine whether the user's requested tasks include tests.
  #
  # The unit of registration is the root namespace (e.g. 'test', 'gcov'), not the
  # full task name. This handles all Rake task name forms uniformly:
  #   - Explicitly named tasks  (test:all)
  #   - Rule-synthesized tasks  (test:foo_file)
  #   - Bare top-level aliases  (test)
  # All share the same root namespace and are therefore all covered once that
  # namespace is registered.
  #
  # Algorithm per file:
  #   1. Skip the file if no marker regex matches the full content (fast pre-check).
  #   2. For each line matching any marker, search backwards to find the
  #      enclosing `namespace` declaration.
  #   3. Resolve the namespace identifier to a string (see find_enclosing_namespace).
  #   4. Register the namespace string with the provided tags.
  #
  # This method is called twice in the Ceedling lifecycle:
  #
  #   Pass 1 — Early, from bin/cli_helper.rb before .rake files are loaded.
  #     constants.rb is already required, so stock constants (TEST_SYM, RELEASE_SYM,
  #     UTILS_SYM) resolve correctly via Object.const_get. Plugin-specific constants
  #     (GCOV_SYM, VALGRIND_SYM, BULLSEYE_SYM, etc.) are defined in plugin lib/ files
  #     that have not been loaded yet, causing Object.const_get to raise NameError.
  #
  #   Pass 2 — After .rake files are loaded in rakefile.rb.
  #     All plugin lib/ paths have been added to $LOAD_PATH and all constants are
  #     defined. Object.const_get succeeds. The registry is cleared and rebuilt.
  #
  # Unresolvable constants (NameError in Pass 1) are handled by the _SYM convention
  # fallback in find_enclosing_namespace.
  def register_tasks(rakefile_paths, markers:, tags:)
    rakefile_paths.each do |filepath|
      begin
        content = File.read( filepath )
      rescue
        next  # Skip unreadable files without failing
      end

      next unless markers.any? { |m| content.match?( m ) }

      lines = content.lines

      lines.each_with_index do |line, idx|
        next unless markers.any? { |m| line.match?( m ) }

        namespace_name = find_enclosing_namespace( lines, idx )
        next if namespace_name.nil?

        @namespace_tags[namespace_name] ||= []
        tags.each do |tag|
          @namespace_tags[namespace_name] << tag unless @namespace_tags[namespace_name].include?( tag )
        end
      end
    end
  end

  # Clears all test-tagged namespaces and re-scans for test pipeline invocations.
  # The delete_if ensures Pass 2 replaces Pass 1 results cleanly without
  # disturbing release-tagged entries registered independently.
  def register_test_tasks(rakefile_paths)
    @namespace_tags.delete_if { |_, tags| tags.include?( TAG_TEST ) }
    register_tasks(
      rakefile_paths, 
      markers: [
        MARKER_TEST_TASKS_SETUP_AND_INVOKE,
        MARKER_TEST_TASKS_RAKE_INVOKE
        ],
      tags: TAGS_TEST
    )
  end

  # Clears all release-tagged namespaces and re-scans for release pipeline invocations.
  def register_release_tasks(rakefile_paths)
    @namespace_tags.delete_if { |_, tags| tags.include?( TAG_RELEASE ) }
    register_tasks( rakefile_paths, markers: [MARKER_RELEASE_TASKS], tags: TAGS_RELEASE )
  end

  private

  # Searches backwards from from_idx to find the enclosing `namespace` declaration.
  # Returns the resolved namespace string, or nil if no namespace is found.
  #
  # Namespace identifier resolution:
  #   :symbol  → strip leading ':' → 'symbol'
  #   "string" → strip surrounding quotes
  #   CONSTANT → Object.const_get → .to_s
  #
  # Handling constants-as-symbols in namespace declarations (e.g. `namespace GCOV_SYM do`):
  # Plugin constants not yet loaded in Pass 1 raise NameError. Ceedling plugin constants
  # follow the naming convention NAME_SYM where NAME is the Rake namespace string
  # (e.g. GCOV_SYM → 'gcov', VALGRIND_SYM → 'valgrind', BULLSEYE_SYM → 'bullseye').
  # The rescue block strips '_SYM' and downcases to infer the correct namespace name.
  # Constants that don't follow this convention fall back to raw.downcase.
  def find_enclosing_namespace(lines, from_idx)
    namespace_name = nil

    (from_idx - 1).downto(0) do |i|
      stripped = lines[i].strip

      if namespace_name.nil? && (m = stripped.match( /\Anamespace\s+(.+?)\s+do/ ))
        raw = m[1].strip
        namespace_name =
          if raw.start_with?( ':' )
            raw[1..]                        # :symbol → 'symbol'
          elsif raw =~ /^[A-Z_]+$/
            begin
              Object.const_get( raw ).to_s  # CONSTANT → resolve at runtime
            rescue NameError
              # Plugin constant not yet loaded (Pass 1 only).
              # Convention: NAME_SYM constants use NAME as the namespace string.
              raw.end_with?( '_SYM' ) ? raw.delete_suffix( '_SYM' ).downcase : raw.downcase
            end
          else
            raw.delete( "'\"" )             # 'string' or "string" → strip quotes
          end
        break
      end
    end

    namespace_name
  end

end
