# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'yaml'
require 'contract/contract'

module Contract

  # One contract row, as its file states it. `legs` always holds at least one leg.
  Row = Struct.new(
    :id, :title, :platforms, :platform_note, :modes, :plugins, :tree, :project, :steps,
    :legs, :divergences, :target, :path,
    keyword_init: true
  ) do
    # Every mode and leg the row runs, as the names its recorded sections use
    def variants
      return modes.flat_map { |mode| legs.map { |leg| Variant.new( mode: mode, leg: leg ) } }
    end

    def partials?
      return project.dig( :project, :use_partials ) == true
    end
  end

  # One way to build a row. The default leg has no name. A named leg adds plugins and
  # configuration, may replace the steps, and may need a tool or another compiler.
  Leg = Struct.new( :name, :plugins, :project, :steps, :requires, :cc, :note, keyword_init: true ) do
    def default?
      return name.nil?
    end
  end

  # One mode of one leg
  Variant = Struct.new( :mode, :leg, keyword_init: true ) do
    def key
      return leg.default? ? mode : "#{mode}/#{leg.name}"
    end
  end

  # One step of a row's build. `arg` is a task for `build`, files for `write`, paths for
  # `delete`, and nil for `clobber`.
  Step = Struct.new( :kind, :arg, keyword_init: true ) do
    def build?
      return kind == 'build'
    end
  end

  # A declared difference between Ceedling and the compiler at one resolved entry
  Divergence = Struct.new( :at, :kind, :note, keyword_init: true )

  # Reads row files and refuses any it cannot use exactly.
  #
  # Every key is checked, so a misspelled field fails loudly instead of being ignored.
  module Loader

    AREAS        = %w[RES MOCK PART LINK GEN ISO DELTA COV ORC].freeze
    ROW_KEYS     = %w[id title platforms platform_note modes plugins tree project steps legs divergences target].freeze
    LEG_KEYS     = %w[plugins project steps requires cc note].freeze
    STEP_KINDS   = %w[build write delete clobber].freeze
    DIVERGENCE_KEYS  = %w[at kind note].freeze
    DIVERGENCE_KINDS = %w[defect convention].freeze
    DEFAULT_STEPS    = [Step.new( kind: 'build', arg: 'test:all' )].freeze

    # Every row in `dir`, in ID order
    def self.all(dir = ROWS_DIR)
      return Dir.glob( File.join( dir, '*.yml' ) ).sort.map { |path| load( path ) }
    end

    def self.load(path)
      data = YAML.safe_load( File.read( path ), permitted_classes: [Symbol], aliases: false )
      row  = parse( data, source: path )

      expected = File.basename( path, '.yml' )
      fail!( path, "id #{row.id} does not match its filename #{expected}" ) unless row.id == expected

      row.path = path
      return row
    end

    # A Row from a row file's parsed content
    def self.parse(data, source: 'row')
      fail!( source, 'a row is a mapping' ) unless data.is_a?( Hash )
      keys!( source, data, ROW_KEYS, 'row' )

      id = data['id']
      fail!( source, "id #{id.inspect} is not an area code and three digits, such as ISO-001" ) unless id.is_a?( String ) && id.match?( /\A(#{AREAS.join( '|' )})-\d{3}\z/ )

      title = data['title']
      fail!( source, 'title must be a non-empty string' ) unless title.is_a?( String ) && !title.strip.empty?

      platforms = list( source, data, 'platforms', PLATFORMS )
      note      = data['platform_note']
      if platforms.sort != PLATFORMS.sort
        fail!( source, 'a row that narrows its platforms gives the reason in platform_note' ) unless note.is_a?( String ) && !note.strip.empty?
      end

      modes = list( source, data, 'modes', MODES, default: nil )
      fail!( source, 'modes must name at least one :use_test_preprocessor value' ) if modes.nil? || modes.empty?

      project = data['project'] || {}
      fail!( source, 'project must be a mapping of project file sections' ) unless project.is_a?( Hash )

      row = Row.new(
        id:            id,
        title:         title,
        platforms:     platforms,
        platform_note: note,
        modes:         modes,
        plugins:       strings( source, data, 'plugins' ),
        tree:          tree( source, data['tree'], 'tree', required: true ),
        project:       project,
        steps:         steps( source, data['steps'] ) || DEFAULT_STEPS,
        legs:          legs( source, data['legs'] ),
        divergences:   divergences( source, data['divergences'] ),
        target:        data['target']
      )

      target = data['target']
      fail!( source, 'target maps each variant key to its promised build reports' ) unless target.nil? || (target.is_a?( Hash ) && target.values.all? { |builds| builds.is_a?( Array ) && builds.all? { |build| build.is_a?( Hash ) } })

      fail!( source, 'Partials force :use_test_preprocessor :all, so a Partials row lists only the all mode' ) if row.partials? && row.modes != ['all']

      return row
    end

    def self.fail!(source, message)
      raise RowError, "#{source}: #{message}"
    end

    def self.keys!(source, hash, allowed, what)
      unknown = hash.keys.map( &:to_s ) - allowed
      fail!( source, "unknown #{what} key#{unknown.size > 1 ? 's' : ''} #{unknown.join( ', ' )}" ) unless unknown.empty?
    end

    # A list of names, each one of `allowed`. Absent, it is `default`, every allowed name.
    def self.list(source, data, key, allowed, default: allowed)
      value = data[key]
      return default.nil? ? nil : default.dup if value.nil?

      fail!( source, "#{key} must be a list" ) unless value.is_a?( Array )
      value = value.map( &:to_s )
      unknown = value - allowed
      fail!( source, "#{key} names #{unknown.join( ', ' )}, not one of #{allowed.join( ', ' )}" ) unless unknown.empty?
      return value
    end

    def self.strings(source, data, key)
      value = data[key] || []
      fail!( source, "#{key} must be a list of names" ) unless value.is_a?( Array ) && value.all? { |item| item.is_a?( String ) }
      return value
    end

    # Files by path, each with its text
    def self.tree(source, value, what, required: false)
      return {} if value.nil? && !required

      fail!( source, "#{what} must map each file path to its content" ) unless value.is_a?( Hash ) && !value.empty?
      value.each do |path, content|
        fail!( source, "#{what} path #{path.inspect} must be a string" ) unless path.is_a?( String )
        fail!( source, "#{what} file #{path} needs text content" ) unless content.is_a?( String )
      end
      return value
    end

    def self.steps(source, value)
      return nil if value.nil?

      fail!( source, 'steps must be a list' ) unless value.is_a?( Array ) && !value.empty?
      steps = value.map do |step|
        fail!( source, 'each step is a mapping of one step kind' ) unless step.is_a?( Hash ) && step.size == 1
        keys!( source, step, STEP_KINDS, 'step' )
        kind, arg = step.first
        kind = kind.to_s
        case kind
        when 'build'
          fail!( source, 'a build step names a task' ) unless arg.is_a?( String ) && !arg.strip.empty?
        when 'write'
          tree( source, arg, 'write step', required: true )
        when 'delete'
          fail!( source, 'a delete step lists paths' ) unless arg.is_a?( Array ) && !arg.empty? && arg.all? { |path| path.is_a?( String ) }
        when 'clobber'
          fail!( source, 'a clobber step takes no argument' ) unless arg.nil? || arg == true
          arg = nil
        end
        Step.new( kind: kind, arg: arg )
      end

      fail!( source, 'steps need at least one build step' ) unless steps.any?( &:build? )
      return steps
    end

    def self.legs(source, value)
      return [Leg.new( plugins: [], project: {}, steps: nil, requires: [], cc: nil )] if value.nil?

      fail!( source, 'legs must map each leg name to its settings' ) unless value.is_a?( Hash ) && !value.empty?
      return value.map do |name, settings|
        settings ||= {}
        fail!( source, "leg #{name} must be a mapping" ) unless settings.is_a?( Hash )
        fail!( source, "leg name #{name.inspect} must be a word" ) unless name.is_a?( String ) && name.match?( /\A[a-z0-9_]+\z/ )
        keys!( source, settings, LEG_KEYS, "leg #{name}" )

        project = settings['project'] || {}
        fail!( source, "leg #{name} project must be a mapping" ) unless project.is_a?( Hash )
        cc = settings['cc']
        fail!( source, "leg #{name} cc must name a compiler" ) unless cc.nil? || (cc.is_a?( String ) && !cc.strip.empty?)

        Leg.new(
          name:     name,
          plugins:  strings( source, settings, 'plugins' ),
          project:  project,
          steps:    steps( source, settings['steps'] ),
          requires: strings( source, settings, 'requires' ),
          cc:       cc,
          note:     settings['note']
        )
      end
    end

    def self.divergences(source, value)
      return [] if value.nil?

      fail!( source, 'divergences must be a list' ) unless value.is_a?( Array )
      return value.map do |item|
        fail!( source, 'each divergence is a mapping' ) unless item.is_a?( Hash )
        keys!( source, item, DIVERGENCE_KEYS, 'divergence' )
        at, kind, note = item.values_at( 'at', 'kind', 'note' )
        fail!( source, "divergence at #{at.inspect} must name a resolved entry, as `resolved <includer> <directive>`" ) unless at.is_a?( String ) && at.start_with?( 'resolved ' )
        fail!( source, "divergence kind #{kind.inspect} is not one of #{DIVERGENCE_KINDS.join( ', ' )}" ) unless DIVERGENCE_KINDS.include?( kind )
        fail!( source, 'each divergence explains itself in a note' ) unless note.is_a?( String ) && !note.strip.empty?
        Divergence.new( at: at.delete_prefix( 'resolved ' ), kind: kind, note: note )
      end
    end

  end

end
