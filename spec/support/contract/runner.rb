# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'json'
require 'yaml'
require 'open3'
require 'fileutils'
require 'contract/contract'
require 'contract/loader'
require 'contract/tree_writer'
require 'contract/oracle'
require 'contract/report'

module Contract

  # Builds one row with this checkout's own Ceedling and reports each build step.
  #
  # Each variant, a mode of one leg, gets a fresh workspace. The row's tree is written
  # there with a project file merged over a minimal one, and `bin/ceedling` runs in a
  # subprocess with `:which_ceedling` naming this checkout and the probe plugin enabled.
  # After each build step the runner reads the probe's record, builds the report, and asks
  # the oracle about the tree as it then stands.
  class Runner

    # One build step's report and the compiler's answers for the tree it built
    Build = Struct.new( :task, :report, :compiler, :output, :probe, keyword_init: true )

    # One variant's builds. `skipped` gives the reason a variant could not run here.
    Result = Struct.new( :variant, :builds, :seconds, :skipped, keyword_init: true )

    # The project file every row starts from
    BASE_PROJECT = {
      project: {
        build_root:            'build',
        use_mocks:             true,
        use_backtrace:         :none,
        which_ceedling:        CHECKOUT
      },
      paths: {
        test:   ['test/**'],
        source: ['src/**']
      },
      cmock: {
        mock_prefix: 'mock_'
      }
    }.freeze

    def initialize(row)
      @row = row
    end

    def run(variant)
      started = now
      reason  = skip_reason( variant.leg )
      return Result.new( variant: variant, builds: [], seconds: 0.0, skipped: reason ) unless reason.nil?

      builds = []
      Dir.mktmpdir( 'contract-probe' ) do |probe_root|
        install_probe( probe_root )

        Workspace.create do |workspace|
          tree    = @row.tree.dup
          project = project_for( variant, workspace, probe_root )
          oracle  = Oracle.new( project: project, cc: variant.leg.cc || Contract.cc )
          objects = {}

          TreeWriter.write( workspace, tree )
          File.write( File.join( workspace.app, 'project.yml' ), project_yaml( project ) )

          steps_for( variant ).each do |step|
            case step.kind
            when 'build'
              builds << build( step.arg, workspace, probe_root, tree, project, oracle, objects, builds.size + 1 )
            when 'clobber'
              ceedling( 'clobber', workspace, File.join( probe_root, 'clobber.json' ) )
            else
              tree = TreeWriter.apply( tree, step )
              step.kind == 'write' ? TreeWriter.write( workspace, step.arg ) : TreeWriter.delete( workspace, step.arg )
            end
          end
        end
      end

      return Result.new( variant: variant, builds: builds, seconds: now - started, skipped: nil )
    end

    # The project configuration a variant builds with, before it is written as YAML
    def project_for(variant, workspace, probe_root)
      project = merge( BASE_PROJECT, @row.project )
      project = merge( project, variant.leg.project )
      project = merge( project, { project: { use_test_preprocessor: variant.mode.to_sym } } )

      plugins = project[:plugins] || {}
      project[:plugins] = plugins.merge(
        load_paths: [probe_root] + Array( plugins[:load_paths] ),
        enabled:    ['contract_probe'] + @row.plugins + variant.leg.plugins + Array( plugins[:enabled] )
      )

      return expand( project, workspace )
    end

    private

    def now
      return Process.clock_gettime( Process::CLOCK_MONOTONIC )
    end

    def skip_reason(leg)
      missing = leg.requires.reject { |tool| Contract.tool?( tool ) }
      missing << leg.cc if leg.cc && !Contract.tool?( leg.cc )
      return nil if missing.empty?

      return "leg #{leg.name} needs #{missing.uniq.join( ', ' )}, which this machine lacks"
    end

    def steps_for(variant)
      return variant.leg.steps || @row.steps
    end

    def install_probe(probe_root)
      lib = File.join( probe_root, 'contract_probe', 'lib' )
      FileUtils.mkdir_p( lib )
      FileUtils.cp( PROBE_FILE, File.join( lib, 'contract_probe.rb' ) )
    end

    def build(task, workspace, probe_root, tree, project, oracle, objects, ordinal)
      record = File.join( probe_root, "build-#{ordinal}.json" )
      output, status = ceedling( task, workspace, record )
      probe = File.file?( record ) ? JSON.parse( File.read( record ) ) : nil

      report = Report.build(
        probe:       probe,
        output:      output,
        status:      status,
        workspace:   workspace,
        tree:        tree,
        mock_prefix: project.dig( :cmock, :mock_prefix ).to_s,
        objects:     objects
      )

      return Build.new( task: task, report: report, compiler: oracle.resolve( tree ), output: output, probe: probe )
    end

    # Runs bin/ceedling in the project root. Decorations are off, so every platform logs
    # the same text.
    def ceedling(task, workspace, record)
      FileUtils.rm_f( record )
      env = { 'CONTRACT_PROBE_OUT' => record, 'CEEDLING_DECORATORS' => '0' }
      command = [RbConfig.ruby, File.join( CHECKOUT, 'bin', 'ceedling' ), task]
      out, err, status = Open3.capture3( env, *command, chdir: workspace.app )
      return (out + err).encode( 'UTF-8', invalid: :replace, undef: :replace ), status.exitstatus
    end

    # Hashes merge key by key. Any other value, a list included, replaces the one before.
    def merge(base, over)
      return base.merge( over ) do |_key, old, new|
        old.is_a?( Hash ) && new.is_a?( Hash ) ? merge( old, new ) : new
      end
    end

    def expand(value, workspace)
      case value
      when Hash   then value.to_h { |key, item| [key, expand( item, workspace )] }
      when Array  then value.map { |item| expand( item, workspace ) }
      when String then workspace.expand( value )
      else value
      end
    end

    # Psych writes Symbol keys and values in the `:key:` form a project file uses
    def project_yaml(project)
      return YAML.dump( project )
    end

  end

end
