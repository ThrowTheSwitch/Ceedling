# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/exceptions'

$LOAD_PATH.unshift( File.expand_path( '../../../plugins/dependencies/lib', __dir__ ) )

require 'dependency_environment'

# A plain hash stands in for ENV, so nothing here changes the process environment
describe DependencyEnvironment do

  def inside(entries, env)
    seen = nil
    described_class.new( entries, dependency: 'dep' ).apply( env ) { seen = env.dup }
    return seen
  end

  it 'sets, appends to, and removes text from variables while its block runs' do
    env  = { 'PATH' => '/bin', 'FLAGS' => '-O2 -g' }
    seen = inside( ['CC = clang', 'PATH+=:/opt/bin', 'FLAGS-=-g'], env )

    expect(seen).to eq( 'PATH' => '/bin:/opt/bin', 'FLAGS' => '-O2 ', 'CC' => 'clang' )
  end

  # Appending needs its own delimiter, such as the space between compiler flags
  it 'keeps the text after += and -= exactly, leading spaces included' do
    seen = inside( ['CFLAGS+= -mcpu=m4', 'LDFLAGS-= -lm'], { 'CFLAGS' => '-O2', 'LDFLAGS' => '-lc -lm' } )

    expect(seen).to eq( 'CFLAGS' => '-O2 -mcpu=m4', 'LDFLAGS' => '-lc' )
  end

  it 'appends to and removes from a variable that is not set' do
    expect(inside( ['A+=x', 'B-=y'], {} )).to eq( 'A' => 'x', 'B' => '' )
  end

  it 'restores every variable afterward, removing those it added' do
    env = { 'PATH' => '/bin' }
    described_class.new( ['PATH+=:/opt', 'CC=clang'], dependency: 'dep' ).apply( env ) { nil }

    expect(env).to eq( 'PATH' => '/bin' )
  end

  it 'restores the environment even when the block raises' do
    env = {}

    expect { described_class.new( ['CC=clang'], dependency: 'dep' ).apply( env ) { raise 'boom' } }.to raise_error( 'boom' )
    expect(env).to eq( {} )
  end

  it 'returns what its block returns' do
    expect(described_class.new( [], dependency: 'dep' ).apply( {} ) { 42 }).to eq( 42 )
  end

  it 'refuses an entry that is not an assignment' do
    expect { described_class.new( ['JUSTANAME'], dependency: 'dep' ) }.to raise_error( CeedlingException, /`JUSTANAME`.*dep/ )
  end

end
