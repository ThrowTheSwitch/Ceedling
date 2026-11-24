# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'contract/oracle'

describe Contract::Oracle do

  def oracle( include: ['src'], extra: {} )
    return described_class.new( project: { paths: { test: ['test/**'], include: include } }.merge( extra ) )
  end

  it 'answers a quoted include from its includer directory first, as the compiler does' do
    tree = {
      'src/a/foo.h'    => "int a;\n",
      'src/a/helper.h' => "#include \"foo.h\"\n",
      'src/foo.h'      => "int b;\n"
    }
    answers = oracle.resolve( tree )
    expect( answers['src/a/helper.h "foo.h"'] ).to eq( 'src/a/foo.h' )
  end

  it 'skips the includer directory for an angle include' do
    tree = {
      'src/a/foo.h'    => "int a;\n",
      'src/a/helper.h' => "#include <foo.h>\n",
      'src/foo.h'      => "int b;\n"
    }
    answers = oracle.resolve( tree )
    expect( answers['src/a/helper.h <foo.h>'] ).to eq( 'src/foo.h' )
  end

  it 'answers missing where no file is found, and <system> for a system header' do
    tree = { 'test/test_a.c' => "#include \"nothing.h\"\n#include <stddef.h>\n#include \"unity.h\"\n" }
    answers = oracle.resolve( tree )
    expect( answers ).to eq( 'test/test_a.c "nothing.h"' => 'missing', 'test/test_a.c <stddef.h>' => '<system>' )
  end

  it 'normalizes the ./ a -I . search adds' do
    tree = {
      'src/drivers/bar.h' => "#include \"foo.h\"\n",
      'src/drivers/foo.h' => "int a;\n",
      'test/t_dot.c'      => "#include \"src/drivers/bar.h\"\n"
    }
    answers = oracle( include: ['.'] ).resolve( tree )
    expect( answers['test/t_dot.c "src/drivers/bar.h"'] ).to eq( 'src/drivers/bar.h' )
    expect( answers['src/drivers/bar.h "foo.h"'] ).to eq( 'src/drivers/foo.h' )
  end

  it 'searches the configured paths in order, a glob expanding to its base then every directory below' do
    Contract::Workspace.create do |workspace|
      Contract::TreeWriter.write( workspace, { 'src/b/x.h' => '', 'src/a/y/z.h' => '', 'lib/q.h' => '' } )
      order = oracle( include: ['lib', 'src/**', '-:src/a/y'] ).search_order( workspace )
      expect( order ).to eq( ['test', 'lib', 'src', 'src/a', 'src/b'] )
    end
  end

  it 'answers a Partials directive by the module header its expanded macro names' do
    tree = {
      'src/drivers/sensor.h' => "int s;\n",
      'test/test_s.c'        => "#include TEST_PARTIAL_MODULE_AT(src/drivers, sensor)\n#include MOCK_PARTIAL_PUBLIC_MODULE(sensor)\n"
    }
    answers = oracle( include: ['.', 'src/**'] ).resolve( tree )
    expect( answers['test/test_s.c TEST_PARTIAL_MODULE_AT(src/drivers, sensor)'] ).to eq( 'src/drivers/sensor.h' )
    expect( answers['test/test_s.c MOCK_PARTIAL_PUBLIC_MODULE(sensor)'] ).to eq( 'src/drivers/sensor.h' )
  end

  it 'expands a Partials argument with the row test defines, as a build does' do
    tree = {
      'src/one/sensor.h' => "int s;\n",
      'test/test_s.c'    => "#include TEST_PARTIAL_MODULE_AT(src/MODDIR, sensor)\n"
    }
    answers = oracle( include: ['.'], extra: { defines: { test: ['MODDIR=one'] } } ).resolve( tree )
    expect( answers['test/test_s.c TEST_PARTIAL_MODULE_AT(src/MODDIR, sensor)'] ).to eq( 'src/one/sensor.h' )
  end

  # The oracle checks its own answers before any row trusts them
  context 'with a compiler that answers wrongly' do
    it 'fails an angle include answered from its includer directory' do
      tree = {
        'src/a/foo.h'    => "int a;\n",
        'src/a/helper.h' => "#include <foo.h>\n",
        'src/foo.h'      => "int b;\n"
      }
      subject = oracle
      allow( subject ).to receive( :run_compiler ).and_return( ". src/a/foo.h\n" )

      expect { subject.resolve( tree ) }.to raise_error( Contract::OracleError, /includer's own directory/ )
    end

    it 'accepts that same answer when a search path names the includer directory' do
      tree = { 'src/a/foo.h' => "int a;\n", 'src/a/helper.h' => "#include <foo.h>\n" }
      subject = oracle( include: ['src/a'] )
      allow( subject ).to receive( :run_compiler ).and_return( ". src/a/foo.h\n" )

      expect( subject.resolve( tree )['src/a/helper.h <foo.h>'] ).to eq( 'src/a/foo.h' )
    end

    it 'fails a probe that gives neither an entry nor a missing-file error' do
      subject = oracle
      allow( subject ).to receive( :run_compiler ).and_return( "internal compiler error\n" )

      expect { subject.resolve( { 'test/test_a.c' => "#include \"a.h\"\n" } ) }.to raise_error( Contract::OracleError, /no -H entry/ )
    end
  end

end
