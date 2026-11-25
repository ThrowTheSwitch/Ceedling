# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'yaml'
require 'fileutils'
require 'contract/contract'

module Contract

  # Reads and writes a row's recorded columns, in `recorded/<ID>.yml`.
  #
  # `compiler` is a list of the oracle's answers, one per build step, stored once for
  # every platform. `current` holds one section per platform, and in it one list per
  # variant of that variant's build reports, each led by its task.
  class Recorder

    attr_reader :row, :path

    def initialize(row, dir: RECORDED_DIR)
      @row  = row
      @path = File.join( dir, "#{row.id}.yml" )
    end

    def recorded
      return { 'id' => row.id } unless File.file?( path )

      return YAML.safe_load( File.read( path ), aliases: false ) || { 'id' => row.id }
    end

    # One platform's recorded builds for a variant, nil when none are recorded
    def current(platform, key)
      return recorded.dig( 'current', platform, key )
    end

    def compiler
      return recorded['compiler']
    end

    # The recorded file with this platform's sections for `results` and the compiler
    # column replaced. Variants that did not run keep what was recorded.
    def merged(platform, results)
      data = recorded
      ran  = results.reject( &:skipped )

      data['compiler'] = Recorder.compiler_column( ran.first ) unless ran.empty?
      data['current'] ||= {}
      data['current'][platform] ||= {}
      ran.each { |result| data['current'][platform][result.variant.key] = Recorder.section( result ) }

      # A section for a variant the row no longer has would never be compared again
      keys = row.variants.map( &:key )
      data['current'] = data['current'].transform_values { |sections| sections.select { |key, _| keys.include?( key ) }.sort.to_h }
      data['current'] = data['current'].sort.to_h
      return { 'id' => row.id, 'compiler' => data['compiler'], 'current' => data['current'] }
    end

    def write(data, to = path)
      FileUtils.mkdir_p( File.dirname( to ) )
      File.write( to, Recorder.dump( data ) )
    end

    # A variant's builds as its recorded section lists them
    def self.section(result)
      return result.builds.map { |build| { 'task' => build.task }.merge( build.report ) }
    end

    def self.compiler_column(result)
      return result.builds.map( &:compiler )
    end

    # YAML without folded lines, so a diff of a recording shows whole entries
    def self.dump(data)
      return YAML.dump( data, line_width: -1 )
    end

  end

  # Compares live reports with recorded columns and declared divergences
  module Check

    MAX_LINES = 25

    # Every place `actual` differs from `expected`, as `path: expected ... got ...` lines
    def self.diff(expected, actual, at = '')
      if expected.is_a?( Hash ) && actual.is_a?( Hash )
        keys = expected.keys | actual.keys
        return keys.flat_map do |key|
          where = at.empty? ? key.to_s : "#{at} > #{key}"
          next ["#{where}: recorded but not observed"] unless actual.key?( key )
          next ["#{where}: observed but not recorded, #{actual[key].inspect}"] unless expected.key?( key )

          diff( expected[key], actual[key], where )
        end
      end

      if expected.is_a?( Array ) && actual.is_a?( Array ) && expected.size == actual.size && expected.any? { |item| item.is_a?( Hash ) }
        return expected.each_index.flat_map { |index| diff( expected[index], actual[index], "#{at}[#{index}]" ) }
      end

      return [] if expected == actual

      return ["#{at}: recorded #{expected.inspect}, observed #{actual.inspect}"]
    end

    # Raises unless `actual` equals `expected`, naming the first differences
    def self.equal!(expected, actual, what)
      lines = diff( expected, actual )
      return if lines.empty?

      shown = lines.first( MAX_LINES )
      shown << "... and #{lines.size - MAX_LINES} more" if lines.size > MAX_LINES
      raise Mismatch, "#{what} differs from its recording:\n  #{shown.join( "\n  " )}"
    end

    # Each resolved entry where Ceedling and the compiler both answer, and differ
    def self.divergences(resolved, compiler)
      return resolved.each_with_object( {} ) do |(key, value), found|
        next unless compiler.key?( key )

        found[key] = [value, compiler[key]] unless value == compiler[key]
      end
    end

    # Search paths that are Ceedling's own: generated, vendored, or outside the workspace
    CEEDLING_OWN = ['build/', '%{ceedling}', '<'].freeze

    # Raises unless Ceedling searches the header directories in the oracle's order.
    #
    # The oracle builds its `-I` list from the project file, apart from the configurator,
    # so this keeps the two from drifting apart. Ceedling's own paths and its derived
    # paths are left out. So is any directory with no header at or below it, since it
    # can answer no include. A directory above a header counts, as `.` does for
    # "src/drivers/bar.h". Two empty lists prove nothing, so they fail too.
    def self.search_order!(oracle, ceedling, derived:, headers:, what:)
      answers = ->( dir ) { headers.any? { |header| Check.below?( header, dir ) } }
      ours    = ceedling.reject { |dir| dir.start_with?( *CEEDLING_OWN ) || derived.include?( dir ) }.select( &answers )
      theirs  = oracle.select( &answers )

      raise Mismatch, "#{what}: no searched directory holds a header, so no order can be compared" if ours.empty? && theirs.empty?
      return if ours == theirs

      raise Mismatch, "#{what} searches its header directories in another order than the oracle:\n" \
                      "  Ceedling #{ours.inspect}\n  oracle   #{theirs.inspect}"
    end

    # Whether normalized `path` lies at or below directory `dir`. The project root `.`
    # holds every path but a climb out of it or a `%{...}` root.
    def self.below?(path, dir)
      return !path.start_with?( '../', '%' ) if dir == '.'

      return path.start_with?( "#{dir}/" )
    end

    # The executable extension Ceedling's defaults give the running platform
    EXE = Contract.windows? ? '.exe' : '.out'

    # Raises unless each live build matches the sections its own target promises. `%{exe}`
    # in a target is `exe`, so one target names an executable on every platform.
    def self.target!(target, live, what, exe: EXE)
      unless target.size == live.size
        raise Mismatch, "#{what} promises #{target.size} build#{target.size == 1 ? '' : 's'}, and #{live.size} ran"
      end

      target = expand( target, exe )
      equal!( target, live.each_with_index.map { |build, index| promised( target[index], build ) }, what )
    end

    # `value` with `%{exe}` replaced in every key and string
    def self.expand(value, exe)
      case value
      when Hash   then value.to_h { |key, inner| [expand( key, exe ), expand( inner, exe )] }
      when Array  then value.map { |inner| expand( inner, exe ) }
      when String then value.gsub( '%{exe}', exe )
      else value
      end
    end

    # The part of `live` a target speaks for. A mapping promises only the keys it names, at
    # every depth, so a target can promise a test's outcome without its progress lines. A
    # list or a value is compared whole. A named key the report lacks stays out of the part,
    # so the comparison reports it missing.
    def self.promised(promise, live)
      return live unless promise.is_a?( Hash ) && live.is_a?( Hash )

      return promise.each_with_object( {} ) do |(key, value), part|
        part[key] = promised( value, live[key] ) if live.key?( key )
      end
    end

    # Raises for a difference the row does not declare
    def self.declared!(found, declared, what)
      undeclared = found.reject { |key, _| declared.include?( key ) }
      return if undeclared.empty?

      lines = undeclared.map { |key, (current, compiler)| "resolved #{key}: Ceedling #{current.inspect}, compiler #{compiler.inspect}" }
      raise Mismatch, "#{what} shows #{undeclared.size} undeclared divergence#{undeclared.size > 1 ? 's' : ''}:\n  #{lines.join( "\n  " )}"
    end

  end

end
