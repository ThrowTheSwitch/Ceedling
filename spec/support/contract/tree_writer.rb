# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'
require 'tmpdir'
require 'contract/contract'

module Contract

  # The directories one row is written into.
  #
  # The project is `app/` inside `root`, so a tree path `../shared/x.h` lands beside it.
  # `far` is a separate temporary directory, for files far outside the project, which a
  # tree path names as `%{far}/x.h`. Both are resolved through File.realpath, so a temp
  # directory behind a symlink, as on macOS, has one spelling.
  Workspace = Struct.new( :root, :app, :far, keyword_init: true ) do
    # Runs the block with a fresh workspace and removes it afterward
    def self.create
      Dir.mktmpdir( 'contract' ) do |dir|
        Dir.mktmpdir( 'contract-far' ) do |far_dir|
          root = File.realpath( dir )
          far  = File.join( File.realpath( far_dir ), 'deep', 'sdk' )
          app  = File.join( root, 'app' )
          FileUtils.mkdir_p( [app, far] )
          yield new( root: root, app: app, far: far )
        end
      end
    end

    # Substitutes `%{far}` and `%{app}` in a row's text
    def expand(text)
      return text.gsub( '%{far}', far ).gsub( '%{app}', app )
    end

    # The absolute path of a tree path
    def locate(path)
      return File.expand_path( expand( path ), app )
    end
  end

  # Writes a row's files into a workspace, and deletes them for a delete step
  module TreeWriter

    def self.write(workspace, files)
      files.each do |path, content|
        target = workspace.locate( path )
        FileUtils.mkdir_p( File.dirname( target ) )
        File.binwrite( target, workspace.expand( content ) )
      end
    end

    def self.delete(workspace, paths)
      paths.each { |path| FileUtils.rm_rf( workspace.locate( path ) ) }
    end

    # The tree after a step: a write adds or replaces files, and a delete removes every
    # file at or below each path it names
    def self.apply(tree, step)
      case step.kind
      when 'write'  then tree.merge( step.arg )
      when 'delete' then tree.reject { |path, _| step.arg.any? { |gone| path == gone || path.start_with?( "#{gone.chomp( '/' )}/" ) } }
      else tree
      end
    end

  end

end
