# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Path handling across project layouts and the spellings a project file may use for one
# place: through configuration, collection, build-path mapping, and the lookups that invert
# it. Every build file must land inside the build root, distinct inputs must stay distinct,
# and every spelling of one layout must place files alike.
#
# Each example names the gap it probes (GH #1370 and the path handling audit around it).

require 'spec_helper'
require 'path_scenario_harness'

describe 'Path scenarios (integration)' do
  include PathScenarioHarness

  TEST_C = "#include \"unity.h\"\nvoid setUp(void) {}\nvoid tearDown(void) {}\nvoid test_it(void) {}\n"

  def c(name)
    "int #{name}(void) { return 0; }\n"
  end

  def h(name)
    "int #{name}(void);\n"
  end

  # --- Baseline -------------------------------------------------------------------------

  it 'baseline: mirrors same-named files below one plain root, inside the build root' do
    files = {
      'app/src/a/util.c' => c( 'a' ), 'app/src/b/util.c' => c( 'b' ),
      'app/src/a/util.h' => h( 'a' ), 'app/src/b/util.h' => h( 'b' ),
      'app/test/test_u.c' => TEST_C
    }
    in_workspace( files ) do |ws, app|
      scene = scenario( scenario_yaml( ws: ws, app: app, paths: { test: ['test/**'], source: ['src/**'], include: ['src/**'] } ) )
      placed = placements( scene )

      placed.each_value { |paths| expect_inside_build( paths ) }
      expect_distinct( placed[:test_objects], 'test objects' )
      expect_distinct( placed[:release_objects], 'release objects' )
      expect_distinct( placed[:preprocessed], 'preprocessed headers' )
    end
  end

  # --- G1 (#1370): a `..` root beside a header outside the project ------------------------

  # The report's vendor SDK sat at its drive's root, far above the project, so its headers'
  # paths climb past the `..` root. A sibling one level up is truly below `..` and mirrors.
  context 'G1 (#1370): a `..` root beside an include path far outside the project' do
    def files
      {
        'app/src/main.c' => c( 'main' ), 'app/src/main.h' => h( 'main' ),
        'app/test/test_m.c' => TEST_C,
        'vendor/inc/cmsis.h' => h( 'cmsis' )
      }
    end

    [
      ['an absolute vendor path far outside', '%{far}/inc'],
      ['a sibling vendor path', '../vendor/inc']
    ].each do |label, vendor|
      it "places a mock of the vendor header inside the build root, with #{label}" do
        in_workspace( files, far: { 'inc/sdk.h' => h( 'sdk' ) } ) do |ws, app|
          scene = scenario( scenario_yaml( ws: ws, app: app, paths: { test: ['test/**'], source: ['src/**'], include: ['../**', vendor] } ) )
          placed = placements( scene )

          expect_inside_build( placed[:mocks] )
          expect_inside_build( placed[:preprocessed] )
          expect_inside_build( placed[:test_objects] )
        end
      end
    end
  end

  # --- G2: equivalent spellings of one root ------------------------------------------------

  context 'G2: one layout under each spelling of its roots' do
    def files
      {
        'app/src/a/util.c' => c( 'a' ), 'app/src/b/util.c' => c( 'b' ),
        'app/src/a/util.h' => h( 'a' ), 'app/src/b/util.h' => h( 'b' ),
        'app/test/test_u.c' => TEST_C
      }
    end

    def placed_with(spelling, ws, app)
      spell = PathScenarioHarness::ROOT_SPELLINGS[spelling]
      roots = ->(root) { [spell.call( root, ws: ws, app: app )] }
      scene = scenario( scenario_yaml( ws: ws, app: app, paths: { test: roots.( 'test/**' ), source: roots.( 'src/**' ), include: roots.( 'src/**' ) } ) )
      return [scene, relative_placements( scene )]
    end

    (PathScenarioHarness::ROOT_SPELLINGS.keys - [:plain]).each do |spelling|
      it "places every build file as the plain spelling does, with #{spelling} roots", pending: (spelling == :symlink && 'G12: a symlinked spelling is collected as a second file') do
        in_workspace( files, symlink: spelling == :symlink ) do |ws, app|
          _, plain = placed_with( :plain, ws, app )
          scene, spelled = placed_with( spelling, ws, app )

          expect_one_spelling_each( scene[:configurator] )
          expect(spelled).to eq( plain )
        end
      end
    end
  end

  # --- G3 and G13: exclusions ---------------------------------------------------------------

  context 'G3 and G13: a `-:` exclusion' do
    def files
      {
        'app/src/sub/x.c' => c( 'x1' ), 'app/src/exp/sub/x.c' => c( 'x2' ), 'app/src/exp/deep/y.c' => c( 'y' ),
        'app/src/main.h' => h( 'main' ), 'app/test/test_m.c' => TEST_C
      }
    end

    it 'G13: excludes the whole subtree it names', pending: "G13: a `-:` exclusion drops only the directory it names" do
      in_workspace( files ) do |ws, app|
        scene = scenario( scenario_yaml( ws: ws, app: app, paths: { test: ['test/**'], source: ['+:src/**', '-:src/exp'], include: ['src/**'] } ) )

        expect(scene[:configurator].collection_all_source).to match_array( %w[src/sub/x.c] )
      end
    end

    # A file the exclusion fails to drop (G13) must not mirror below the exclusion itself
    it 'G3: is never a root that kept files mirror below' do
      in_workspace( files ) do |ws, app|
        scene = scenario( scenario_yaml( ws: ws, app: app, paths: { test: ['test/**'], source: ['+:src/**', '-:src/exp'], include: ['src/**'] } ) )
        placed = placements( scene )

        expect_distinct( placed[:release_objects], 'release objects' )
      end
    end
  end

  # --- G4: header-to-source correlation ---------------------------------------------------

  context 'G4: a header found beside its source by convention' do
    def files
      {
        'app/include/drv/x.h' => h( 'x' ), 'app/src/drv/x.c' => c( 'x' ),
        'app/components/foo/include/foo.h' => h( 'foo' ), 'app/components/foo/src/foo.c' => c( 'foo' ),
        'app/test/test_x.c' => TEST_C
      }
    end

    {
      'a plain include root'     => ['include/**'],
      'a `./` include root'      => ['./include/**'],
      'an absolute include root' => ['%{app}/include/**']
    }.each do |label, include|
      it "finds the source of a header below #{label}" do
        in_workspace( files ) do |ws, app|
          scene = scenario( scenario_yaml( ws: ws, app: app, paths: { test: ['test/**'], source: ['src/**'], include: include } ) )

          expect(scene[:finder].find_build_input_file( filepath: 'include/drv/x.h', complain: :ignore, context: :test )).to eq( 'src/drv/x.c' )
        end
      end
    end

    it 'finds the source of a header below a glob-middle include root', pending: "G4: a glob-middle include root is matched as written" do
      in_workspace( files ) do |ws, app|
        scene = scenario( scenario_yaml( ws: ws, app: app, paths: { test: ['test/**'], source: ['components/*/src'], include: ['components/*/include'] } ) )

        expect(scene[:finder].find_build_input_file( filepath: 'components/foo/include/foo.h', complain: :ignore, context: :test )).to eq( 'components/foo/src/foo.c' )
      end
    end
  end

  # --- G5 and G6: collisions --------------------------------------------------------------

  context 'G5: the same relative path below two roots' do
    it 'gives each source its own release object', pending: "G5: placement drops the root, so the same path below two roots collides" do
      files = { 'app/src/foo.c' => c( 'a' ), 'app/lib/foo.c' => c( 'b' ), 'app/src/foo.h' => h( 'a' ), 'app/test/test_f.c' => TEST_C }
      in_workspace( files ) do |ws, app|
        scene = scenario( scenario_yaml( ws: ws, app: app, paths: { test: ['test/**'], source: ['src/**', 'lib/**'], include: ['src/**'] } ) )

        expect_distinct( placements( scene )[:release_objects], 'release objects' )
      end
    end
  end

  context 'G6: nested roots' do
    it 'gives a file in the inner root and one in the outer root their own objects', pending: "G6: the longest root wins, dropping the outer prefix" do
      files = { 'app/src/util.c' => c( 'a' ), 'app/src/legacy/util.c' => c( 'b' ), 'app/src/util.h' => h( 'a' ), 'app/test/test_u.c' => TEST_C }
      in_workspace( files ) do |ws, app|
        scene = scenario( scenario_yaml( ws: ws, app: app, paths: { test: ['test/**'], source: ['src/**', 'src/legacy/**'], include: ['src/**'] } ) )
        placed = placements( scene )

        expect_distinct( placed[:test_objects], 'test objects' )
        expect_distinct( placed[:release_objects], 'release objects' )
      end
    end
  end

  # --- G8: outside every root -------------------------------------------------------------

  context 'G8: sources reached only through :files' do
    it 'gives same-named files outside every root their own objects', pending: "G8: a file outside every root is placed flat" do
      files = { 'app/src/main.c' => c( 'main' ), 'app/src/main.h' => h( 'main' ), 'app/a/util.c' => c( 'a' ), 'app/b/util.c' => c( 'b' ), 'app/test/test_m.c' => TEST_C }
      in_workspace( files ) do |ws, app|
        scene = scenario( scenario_yaml( ws: ws, app: app, paths: { test: ['test/**'], source: ['src/**'], include: ['src/**'] }, files: { source: ['a/util.c', 'b/util.c'] } ) )

        expect_distinct( placements( scene )[:release_objects], 'release objects' )
      end
    end
  end

  # --- Sources outside the project --------------------------------------------------------

  context 'sources and headers in a sibling directory' do
    it 'places their build files inside the build root, each its own' do
      files = {
        'shared/src/a/util.c' => c( 'a' ), 'shared/src/b/util.c' => c( 'b' ),
        'shared/src/a/util.h' => h( 'a' ), 'shared/src/b/util.h' => h( 'b' ),
        'app/test/test_u.c' => TEST_C
      }
      in_workspace( files ) do |ws, app|
        scene = scenario( scenario_yaml( ws: ws, app: app, paths: { test: ['test/**'], source: ['../shared/src/**'], include: ['../shared/src/**'] } ) )
        placed = placements( scene )

        placed.each_value { |paths| expect_inside_build( paths ) }
        expect_distinct( placed[:release_objects], 'release objects' )
      end
    end
  end

  # --- G15: a root above the build root --------------------------------------------------

  context 'G15: a root that holds the build root' do
    it 'collects nothing from an existing build directory', pending: "G15: a root holding the build root collects the build tree" do
      files = {
        'app/src/main.c' => c( 'main' ), 'app/src/main.h' => h( 'main' ), 'app/test/test_m.c' => TEST_C,
        'app/build/test/mocks/test/test_m/mock_main.h' => h( 'mock' ), 'app/build/test/runners/test/test_m/test_m_runner.c' => c( 'r' )
      }
      in_workspace( files ) do |ws, app|
        scene = scenario( scenario_yaml( ws: ws, app: app, paths: { test: ['test/**'], source: ['src/**'], include: ['../**'] } ) )

        expect_collections_outside_build( scene[:configurator] )
      end
    end
  end

  # --- G12: the working directory reached through a symlink -------------------------------

  context 'G12: absolute roots spelled through a symlink to the project' do
    it 'collects each file once', pending: "G12: a symlinked spelling is collected as a second file" do
      files = { 'app/src/main.c' => c( 'main' ), 'app/src/main.h' => h( 'main' ), 'app/test/test_m.c' => TEST_C }
      in_workspace( files, symlink: true ) do |ws, app|
        scene = scenario( scenario_yaml( ws: ws, app: app, paths: { test: ['test/**'], source: ['src/**', '%{ws}/link/src/**'], include: ['src/**'] } ) )

        expect_one_spelling_each( scene[:configurator] )
      end
    end
  end
end
