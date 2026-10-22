# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'generate_module'

# Unity's module generator with the test guard style Ceedling configures. Unity wraps
# each test file in `#ifdef <test define>`; the `if` guard wraps it in `#if` instead,
# which coding standards that forbid `#ifdef` require.
class ModuleGeneratorUnity < UnityModuleGenerator

  TEMPLATE_TST_IF = TEMPLATE_TST.sub( '#ifdef ', '#if ' ).freeze

  def files_to_operate_on(module_name, pattern = nil)
    files = super
    return files unless @options[:test_guard] == 'if'

    return files.map { |file| file[:template].equal?( TEMPLATE_TST ) ? file.merge( template: TEMPLATE_TST_IF ) : file }
  end

end
