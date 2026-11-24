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

      data['current'][platform] = data['current'][platform].sort.to_h
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

    # Raises for a difference the row does not declare
    def self.declared!(found, declared, what)
      undeclared = found.reject { |key, _| declared.include?( key ) }
      return if undeclared.empty?

      lines = undeclared.map { |key, (current, compiler)| "resolved #{key}: Ceedling #{current.inspect}, compiler #{compiler.inspect}" }
      raise Mismatch, "#{what} shows #{undeclared.size} undeclared divergence#{undeclared.size > 1 ? 's' : ''}:\n  #{lines.join( "\n  " )}"
    end

  end

end
