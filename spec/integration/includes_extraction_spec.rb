# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for #include extraction and reconciliation.
#
# Each example lays a small C source tree on disk, runs the real GCC preprocessor
# through the real Preprocessinator graph, and asserts the reconciled + sanitized
# include list. No `ceedling` build runs; the only external dependency is `gcc`.
#
# `mode:` selects the path a real build would take:
#   :accurate -- preprocessing enabled, GCC's -fdirectives-only line markers drive
#                user/system categorization
#   :fallback -- no directives-only stream; categorization comes from scanning the
#                original file text with #if/#ifdef tracking
# On a toolchain whose `gcc` ignores -fdirectives-only (Apple Clang), :accurate is
# unavailable and those examples assert against :fallback instead.

require 'spec_helper'
require 'spec_integration_helper'

describe 'Includes extraction (integration)' do
  include_context 'requires gcc'

  before(:all) { @accurate = directives_only_supported? }

  # Runs one fixture through the harness and returns the rendered `#include ...` lines.
  # `search_subdirs` adds further -I roots (each joined to the fixture dir);
  # `fallback: true` forces the text-scan path even where the accurate one is available.
  def extracted(tree, entry, defines: [], fallback: false, search_subdirs: [])
    with_source_tree(tree) do |dir|
      harness = build_includes_harness(dir)
      list = harness.reconcile(
        file: File.join(dir, entry), defines: defines,
        search_paths: [dir, *search_subdirs.map { |s| File.join(dir, s) }],
        fallback: fallback || !@accurate
      )
      list.map(&:to_s)
    end
  end

  # --- Basics ------------------------------------------------------------

  it 'extracts a single literal user include' do
    tree = {
      'widget.c' => %(#include "widget.h"\nint w(void){return 0;}\n),
      'widget.h' => %(#ifndef WIDGET_H\n#define WIDGET_H\nint w(void);\n#endif\n)
    }
    expect(extracted(tree, 'widget.c')).to eq(['#include "widget.h"'])
  end

  it 'orders system includes ahead of user includes' do
    tree = {
      'gadget.c' => %(#include "gadget.h"\n#include <stddef.h>\nsize_t g(void){return 0;}\n),
      'gadget.h' => %(#ifndef GADGET_H\n#define GADGET_H\nsize_t g(void);\n#endif\n)
    }
    result = extracted(tree, 'gadget.c')
    expect(result).to include('#include <stddef.h>', '#include "gadget.h"')
    expect(result.index { |s| s.start_with?('#include <') })
      .to be < result.index('#include "gadget.h"')
  end

  it 'categorizes an include by GCC search-path origin, not by bracket vs quote punctuation' do
    # Characterization: a project header pulled in with `<...>` (resolved via -I, not a
    # standard search path) comes back rendered as a user include -- the accurate pass
    # keys on where GCC found the header, not on how the directive was written.
    tree = {
      'gadget.c'    => %(#include <gadget_hw.h>\nint g(void){return 0;}\n),
      'gadget_hw.h' => %(#ifndef GADGET_HW_H\n#define GADGET_HW_H\n#define GADGET_REG 0x40\n#endif\n)
    }
    expect(extracted(tree, 'gadget.c')).to eq(['#include "gadget_hw.h"'])
  end

  it 'currently emits a standard-library header once per file in its resolution wrapper chain' do
    # Characterization, not endorsement: <stdint.h> resolves through a compiler wrapper
    # header of the same basename, so the SYSTEM line-marker pass reports it at two
    # distinct paths and reconcile keeps both. The Include value model (out of scope for
    # this work) is where any dedup-by-basename would live.
    tree = {
      'clock.c' => %(#include <stdint.h>\nuint8_t c(void){return 0;}\n)
    }
    result = extracted(tree, 'clock.c')
    expect(result.uniq).to eq(['#include <stdint.h>'])
    expect(result.count('#include <stdint.h>')).to be >= 1
  end

  it 'returns nothing for a file with no includes' do
    tree = { 'solo.c' => %(int s(void) { return 0; }\n) }
    expect(extracted(tree, 'solo.c')).to eq([])
  end

  it 'does not promote a transitively-included header to a top-level include' do
    tree = {
      'thing.c'      => %(#include "thing.h"\nint t(void){return 0;}\n),
      'thing.h'      => %(#ifndef THING_H\n#define THING_H\n#include "thing_impl.h"\nint t(void);\n#endif\n),
      'thing_impl.h' => %(#ifndef THING_IMPL_H\n#define THING_IMPL_H\n#define THING_IMPL 1\n#endif\n)
    }
    expect(extracted(tree, 'thing.c')).to eq(['#include "thing.h"'])
  end

  # --- Conditional guards -------------------------------------------------

  it 'keeps a conditional literal include guarded by a project define (guard true)' do
    tree = {
      'widget.c' => <<~C,
        #ifdef PROJECT_FLAG
        #include "flag_extra.h"
        #endif
        int w(void) { return FLAG_EXTRA_MACRO; }
      C
      'flag_extra.h' => %(#ifndef FLAG_EXTRA_H\n#define FLAG_EXTRA_H\n#define FLAG_EXTRA_MACRO (3)\n#endif\n)
    }
    expect(extracted(tree, 'widget.c', defines: ['PROJECT_FLAG'])).to eq(['#include "flag_extra.h"'])
  end

  it 'keeps a conditional literal include whose guard depends on a sibling-header macro (#1223)' do
    tree = {
      'feature.c' => <<~C,
        #include "feature_config.h"
        #if FEATURE_LEVEL > 1
        #include "feature_extra.h"
        #endif
        int f(void) { return FEATURE_EXTRA_MACRO; }
      C
      'feature_config.h' => %(#ifndef FEATURE_CONFIG_H\n#define FEATURE_CONFIG_H\n#define FEATURE_LEVEL (2)\n#endif\n),
      'feature_extra.h'  => %(#ifndef FEATURE_EXTRA_H\n#define FEATURE_EXTRA_H\n#define FEATURE_EXTRA_MACRO (7)\n#endif\n)
    }
    expect(extracted(tree, 'feature.c')).to contain_exactly(
      '#include "feature_config.h"', '#include "feature_extra.h"'
    )
  end

  it 'drops a sibling-macro-guarded conditional include when the accurate pass evaluates the guard false' do
    skip 'accurate (-fdirectives-only) path unavailable on this toolchain' unless @accurate
    tree = {
      'feature.c' => <<~C,
        #include "feature_config.h"
        #if FEATURE_LEVEL > 9
        #include "feature_extra.h"
        #endif
        int f(void) { return 0; }
      C
      'feature_config.h' => %(#ifndef FEATURE_CONFIG_H\n#define FEATURE_CONFIG_H\n#define FEATURE_LEVEL (2)\n#endif\n),
      'feature_extra.h'  => %(#ifndef FEATURE_EXTRA_H\n#define FEATURE_EXTRA_H\n#define FEATURE_EXTRA_MACRO (7)\n#endif\n)
    }
    expect(extracted(tree, 'feature.c')).to eq(['#include "feature_config.h"'])
  end

  it 'selects the taken branch of an #if / #elif / #else include choice' do
    tree = {
      'radio.c' => <<~C,
        #define BAND 2
        #if BAND == 1
        #include "band_lo.h"
        #elif BAND == 2
        #include "band_mid.h"
        #else
        #include "band_hi.h"
        #endif
        int r(void) { return BAND_MID_MACRO; }
      C
      'band_lo.h'  => %(#ifndef BAND_LO_H\n#define BAND_LO_H\n#define BAND_LO_MACRO 1\n#endif\n),
      'band_mid.h' => %(#ifndef BAND_MID_H\n#define BAND_MID_H\n#define BAND_MID_MACRO 2\n#endif\n),
      'band_hi.h'  => %(#ifndef BAND_HI_H\n#define BAND_HI_H\n#define BAND_HI_MACRO 3\n#endif\n)
    }
    if @accurate
      expect(extracted(tree, 'radio.c')).to eq(['#include "band_mid.h"'])
    else
      # The text-fallback path tracks #if/#elif/#else and keeps only the active branch.
      expect(extracted(tree, 'radio.c', fallback: true)).to eq(['#include "band_mid.h"'])
    end
  end

  # --- Spelling / rendering ------------------------------------------------

  it 'tolerates unusual but legal directive whitespace' do
    tree = {
      'ws.c' => "#   include \"ws.h\"\n\t#\tinclude <stddef.h>\nsize_t f(void){return 0;}\n",
      'ws.h' => %(#ifndef WS_H\n#define WS_H\nsize_t f(void);\n#endif\n)
    }
    result = extracted(tree, 'ws.c')
    expect(result).to include('#include "ws.h"')
    expect(result.any? { |s| s.start_with?('#include <') }).to be true
  end

  # --- Mocks -------------------------------------------------------------

  it 'drops a real header when its mock is also included (mock supersedes)' do
    tree = {
      'consumer.c'   => %(#include "sensor.h"\n#include "mock_sensor.h"\nint c(void){return 0;}\n),
      'sensor.h'      => %(#ifndef SENSOR_H\n#define SENSOR_H\nint sensor_read(void);\n#endif\n),
      'mock_sensor.h' => %(#ifndef MOCK_SENSOR_H\n#define MOCK_SENSOR_H\nint sensor_read(void);\n#endif\n)
    }
    result = extracted(tree, 'consumer.c')
    expect(result.any? { |s| s.include?('mock_sensor.h') }).to be true
    expect(result.any? { |s| s =~ %r{(^|/)sensor\.h"} }).to be false
  end

  # --- Degenerate / resilience ---------------------------------------------

  it 'ignores an #include that appears only inside a comment or a string literal' do
    tree = {
      'noise.c' => <<~C,
        /* #include "commented.h" */
        // #include "commented_too.h"
        const char *s = "#include \\"stringy.h\\"";
        #include "real.h"
        int n(void) { return 0; }
      C
      'real.h' => %(#ifndef REAL_H\n#define REAL_H\nint n(void);\n#endif\n)
    }
    expect(extracted(tree, 'noise.c')).to eq(['#include "real.h"'])
  end

  it 'yields an empty list when the source file has no resolvable includes and no deps' do
    tree = { 'bare.c' => %(int b(void) { return 0; }\n) }
    expect(extracted(tree, 'bare.c')).to eq([])
  end

  # --- More guard shapes -----------------------------------------------

  it 'handles #ifdef, #ifndef, and #if defined() guards consistently' do
    tree = {
      'guards.c' => <<~C,
        #ifdef HAVE_A
        #include "a.h"
        #endif
        #ifndef HAVE_A
        #include "not_a.h"
        #endif
        #if defined(HAVE_B)
        #include "b.h"
        #endif
        int g(void) { return A_MACRO + B_MACRO; }
      C
      'a.h'   => %(#ifndef A_H\n#define A_H\n#define A_MACRO 1\n#endif\n),
      'not_a.h' => %(#ifndef NOT_A_H\n#define NOT_A_H\n#define A_MACRO 0\n#endif\n),
      'b.h'   => %(#ifndef B_H\n#define B_H\n#define B_MACRO 2\n#endif\n)
    }
    result = extracted(tree, 'guards.c', defines: ['HAVE_A', 'HAVE_B'])
    expect(result).to contain_exactly('#include "a.h"', '#include "b.h"')
  end

  it 'keeps a single entry for an include-guarded header pulled in twice' do
    tree = {
      'twice.c' => %(#include "shared.h"\n#include "shared.h"\nint t(void){return SHARED_MACRO;}\n),
      'shared.h' => %(#ifndef SHARED_H\n#define SHARED_H\n#define SHARED_MACRO 5\n#endif\n)
    }
    expect(extracted(tree, 'twice.c')).to eq(['#include "shared.h"'])
  end

  # --- Path / search-path shapes -----------------------------------------

  it 'renders a subdir-qualified quoted include by basename alone when nothing else in the file collides with it' do
    # Ceedling adds every real directory as its own individual search path, so a
    # unique basename already finds the right file -- preserving more of the
    # directive's own written path here would add nothing findable a plain
    # basename doesn't already provide, and (see the collision cases below) can
    # actively break the build the moment it reaches further than any one
    # configured search directory covers.
    tree = {
      'app.c'          => %(#include "drivers/uart.h"\nint a(void){return UART_BAUD;}\n),
      'drivers/uart.h' => %(#ifndef DRIVERS_UART_H\n#define DRIVERS_UART_H\n#define UART_BAUD 115200\n#endif\n)
    }
    expect(extracted(tree, 'app.c')).to eq(['#include "uart.h"'])
  end

  it 'renders a ..-relative include by basename alone when nothing else in the file collides with it' do
    tree = {
      'test/foo.c'      => %(#include "../common/helper.h"\nint f(void){return HELPER_VALUE;}\n),
      'common/helper.h' => %(#ifndef COMMON_HELPER_H\n#define COMMON_HELPER_H\n#define HELPER_VALUE 5\n#endif\n)
    }
    expect(extracted(tree, 'test/foo.c')).to eq(['#include "helper.h"'])
  end

  it 'keeps two headers that share a basename in different directories distinct, disambiguated by their own real paths' do
    tree = {
      'app.c'        => %(#include "hw/config.h"\n#include "app/config.h"\nint a(void){return HW_CFG + APP_CFG;}\n),
      'hw/config.h'  => %(#ifndef HW_CONFIG_H\n#define HW_CONFIG_H\n#define HW_CFG 1\n#endif\n),
      'app/config.h' => %(#ifndef APP_CONFIG_H\n#define APP_CONFIG_H\n#define APP_CFG 2\n#endif\n)
    }
    expect(extracted(tree, 'app.c')).to contain_exactly(
      '#include "hw/config.h"', '#include "app/config.h"'
    )
  end

  it 'grows the disambiguating suffix past one directory level when two colliding paths still share it' do
    tree = {
      'app.c' => %(#include "sensors/adc/config.h"\n#include "drivers/adc/config.h"\nint a(void){return S_CFG + D_CFG;}\n),
      'sensors/adc/config.h' => %(#ifndef SENSORS_ADC_CONFIG_H\n#define SENSORS_ADC_CONFIG_H\n#define S_CFG 1\n#endif\n),
      'drivers/adc/config.h' => %(#ifndef DRIVERS_ADC_CONFIG_H\n#define DRIVERS_ADC_CONFIG_H\n#define D_CFG 2\n#endif\n)
    }
    expect(extracted(tree, 'app.c')).to contain_exactly(
      '#include "sensors/adc/config.h"', '#include "drivers/adc/config.h"'
    )
  end

  it 'composes a non-colliding subdir include (basename-only) with a colliding one (disambiguated) in the same file' do
    tree = {
      'src/app.c'         => <<~C,
        #include "drivers/uart.h"
        #include "hw/config.h"
        #include "local/config.h"
        int a(void) { return UART_BAUD + HW_CFG + LOCAL_CFG; }
      C
      'src/drivers/uart.h' => %(#ifndef DRIVERS_UART_H\n#define DRIVERS_UART_H\n#define UART_BAUD 115200\n#endif\n),
      'src/hw/config.h'    => %(#ifndef HW_CONFIG_H\n#define HW_CONFIG_H\n#define HW_CFG 1\n#endif\n),
      'src/local/config.h' => %(#ifndef LOCAL_CONFIG_H\n#define LOCAL_CONFIG_H\n#define LOCAL_CFG 2\n#endif\n)
    }
    expect(extracted(tree, 'src/app.c')).to contain_exactly(
      '#include "uart.h"', '#include "hw/config.h"', '#include "local/config.h"'
    )
  end

  it 'drops a subdirectory-qualified real header when its mock is also included' do
    # The mock-supersedes filter matches by filename (Includes.sanitize!), unaffected
    # by the real header's own directory nesting -- it's dropped before basename
    # collision/disambiguation ever come into play.
    tree = {
      'consumer.c'       => %(#include "drivers/sensor.h"\n#include "mock_sensor.h"\nint c(void){return 0;}\n),
      'drivers/sensor.h' => %(#ifndef SENSOR_H\n#define SENSOR_H\nint sensor_read(void);\n#endif\n),
      'mock_sensor.h'    => %(#ifndef MOCK_SENSOR_H\n#define MOCK_SENSOR_H\nint sensor_read(void);\n#endif\n)
    }
    result = extracted(tree, 'consumer.c')
    expect(result.any? { |s| s.include?('mock_sensor.h') }).to be true
    expect(result.any? { |s| s =~ %r{(^|/)sensor\.h"} }).to be false
  end

  # --- Partial-source shape ----------------------------------------------

  it 'reconciles a partial-source file with several top-level includes plus a conditional one' do
    tree = {
      'module.c' => <<~C,
        #include "types.h"
        #include "module.h"
        #ifdef WITH_LOGGING
        #include "log.h"
        #endif
        #include "bus.h"
        int m(void) { return 0; }
      C
      'types.h'  => %(#ifndef TYPES_H\n#define TYPES_H\ntypedef int word;\n#endif\n),
      'module.h' => %(#ifndef MODULE_H\n#define MODULE_H\nint m(void);\n#endif\n),
      'log.h'    => %(#ifndef LOG_H\n#define LOG_H\nvoid logmsg(void);\n#endif\n),
      'bus.h'    => %(#ifndef BUS_H\n#define BUS_H\nvoid bus_send(void);\n#endif\n)
    }
    result = extracted(tree, 'module.c', defines: ['WITH_LOGGING'])
    expect(result).to eq(
      ['#include "types.h"', '#include "module.h"', '#include "log.h"', '#include "bus.h"']
    )
  end

  # --- Fallback specifics ----------------------------------------------

  it 'keeps a conditional literal include on the forced text-scan path' do
    # With fallback forced, categorization comes from scanning the file text with
    # #if/#ifdef tracking -- a project-define guard still resolves correctly.
    tree = {
      'ff.c' => <<~C,
        #ifdef ENABLE_X
        #include "x.h"
        #endif
        int f(void) { return X_MACRO; }
      C
      'x.h' => %(#ifndef X_H\n#define X_H\n#define X_MACRO 9\n#endif\n)
    }
    expect(extracted(tree, 'ff.c', defines: ['ENABLE_X'], fallback: true)).to eq(['#include "x.h"'])
  end

  # --- Computed (macro-target) includes (#1267) ------------------------

  # Every fixture here uses the standard stringize dance to build a header name from a
  # macro argument: STR2/STR turn `dev_extra` into `"dev_extra.h"`, so
  # `#include PICK(dev_extra)` is an #include whose target only exists after macro
  # expansion -- invisible to a literal text scan.
  COMPUTED = <<~C
    #define STR2(x) #x
    #define STR(x) STR2(x)
    #define PICK(name) STR(name.h)
  C

  it 'resolves a computed #include guarded by a sibling-header macro (the #1267 shape)' do
    skip 'accurate (-fdirectives-only) path unavailable on this toolchain' unless @accurate
    tree = {
      'widget.c' => <<~C,
        #include "device_config.h"
        #{COMPUTED}
        #if DEVICE_COUNT > 1
        #include PICK(device_extra)
        #endif
        int w(void) { return DEVICE_EXTRA_MACRO; }
      C
      'device_config.h' => %(#ifndef DEVICE_CONFIG_H\n#define DEVICE_CONFIG_H\n#define DEVICE_COUNT 2\n#endif\n),
      'device_extra.h'  => %(#ifndef DEVICE_EXTRA_H\n#define DEVICE_EXTRA_H\n#define DEVICE_EXTRA_MACRO (42)\n#endif\n)
    }
    expect(extracted(tree, 'widget.c')).to contain_exactly(
      '#include "device_config.h"', '#include "device_extra.h"'
    )
  end

  it 'does not resolve a computed #include whose guard the accurate pass evaluates false' do
    skip 'accurate (-fdirectives-only) path unavailable on this toolchain' unless @accurate
    tree = {
      'widget.c' => <<~C,
        #include "device_config.h"
        #{COMPUTED}
        #if DEVICE_COUNT > 9
        #include PICK(device_extra)
        #endif
        int w(void) { return 0; }
      C
      'device_config.h' => %(#ifndef DEVICE_CONFIG_H\n#define DEVICE_CONFIG_H\n#define DEVICE_COUNT 2\n#endif\n),
      'device_extra.h'  => %(#ifndef DEVICE_EXTRA_H\n#define DEVICE_EXTRA_H\n#define DEVICE_EXTRA_MACRO (42)\n#endif\n)
    }
    expect(extracted(tree, 'widget.c')).to eq(['#include "device_config.h"'])
  end

  it 'keeps a single entry for an unguarded computed #include the bare pass already resolves' do
    # No guard: the bare gcc pass sees the same-file STR/PICK macros (a -D define is
    # visible even in the isolated copy) and -MG makes the missing header phony, so it
    # already lands in `bare`. The computed-include path adds it too; dedup by filename
    # keeps exactly one.
    tree = {
      'widget.c' => <<~C,
        #{COMPUTED}
        #include PICK(solo_device)
        int w(void) { return 0; }
      C
      'solo_device.h' => %(#ifndef SOLO_DEVICE_H\n#define SOLO_DEVICE_H\nint sd(void);\n#endif\n)
    }
    expect(extracted(tree, 'widget.c')).to eq(['#include "solo_device.h"'])
  end

  it 'resolves each of two adjacent computed #includes by its own guard' do
    skip 'accurate (-fdirectives-only) path unavailable on this toolchain' unless @accurate
    tree = {
      'widget.c' => <<~C,
        #include "device_config.h"
        #{COMPUTED}
        #if DEVICE_COUNT > 1
        #include PICK(dev_on)
        #endif
        #if DEVICE_COUNT > 9
        #include PICK(dev_off)
        #endif
        int w(void) { return DEV_ON_MACRO; }
      C
      'device_config.h' => %(#ifndef DEVICE_CONFIG_H\n#define DEVICE_CONFIG_H\n#define DEVICE_COUNT 2\n#endif\n),
      'dev_on.h'  => %(#ifndef DEV_ON_H\n#define DEV_ON_H\n#define DEV_ON_MACRO 1\n#endif\n),
      'dev_off.h' => %(#ifndef DEV_OFF_H\n#define DEV_OFF_H\n#define DEV_OFF_MACRO 0\n#endif\n)
    }
    expect(extracted(tree, 'widget.c')).to contain_exactly(
      '#include "device_config.h"', '#include "dev_on.h"'
    )
  end

  it 'resolves a computed #include that targets a project header with bracket syntax' do
    skip 'accurate (-fdirectives-only) path unavailable on this toolchain' unless @accurate
    tree = {
      'widget.c' => <<~C,
        #include "device_config.h"
        #define BR(x) <x.h>
        #if DEVICE_COUNT > 1
        #include BR(bracket_device)
        #endif
        int w(void) { return BRACKET_DEVICE_MACRO; }
      C
      'device_config.h'  => %(#ifndef DEVICE_CONFIG_H\n#define DEVICE_CONFIG_H\n#define DEVICE_COUNT 2\n#endif\n),
      'bracket_device.h' => %(#ifndef BRACKET_DEVICE_H\n#define BRACKET_DEVICE_H\n#define BRACKET_DEVICE_MACRO 7\n#endif\n)
    }
    # Rendered as a user include: reconciliation keys on where GCC found the header
    # (a project -I path), not on the directive's punctuation -- same as the literal
    # bracket-vs-quote characterization above.
    expect(extracted(tree, 'widget.c')).to contain_exactly(
      '#include "device_config.h"', '#include "bracket_device.h"'
    )
  end

  it 'resolves a sibling-macro-guarded computed #include split across a backslash continuation' do
    skip 'accurate (-fdirectives-only) path unavailable on this toolchain' unless @accurate
    # GCC's -fdirectives-only attributes a consumed multi-line directive's own entering
    # marker to its LAST physical line, not its first -- computed_include_source_lines
    # now reports that same last line (ParsingParcels#code_lines_with_num's 3rd yielded
    # value), so the two agree.
    tree = {
      'widget.c' => <<~C,
        #include "device_config.h"
        #{COMPUTED}
        #if DEVICE_COUNT > 1
        #include \\
          PICK(device_extra)
        #endif
        int w(void) { return DEVICE_EXTRA_MACRO; }
      C
      'device_config.h' => %(#ifndef DEVICE_CONFIG_H\n#define DEVICE_CONFIG_H\n#define DEVICE_COUNT 2\n#endif\n),
      'device_extra.h'  => %(#ifndef DEVICE_EXTRA_H\n#define DEVICE_EXTRA_H\n#define DEVICE_EXTRA_MACRO (42)\n#endif\n)
    }
    expect(extracted(tree, 'widget.c')).to contain_exactly(
      '#include "device_config.h"', '#include "device_extra.h"'
    )
  end

  it 'resolves the same shape split across a 3-physical-line continuation' do
    skip 'accurate (-fdirectives-only) path unavailable on this toolchain' unless @accurate
    tree = {
      'widget.c' => <<~C,
        #include "device_config.h"
        #{COMPUTED}
        #if DEVICE_COUNT > 1
        #include \\
          PICK( \\
          device_extra)
        #endif
        int w(void) { return DEVICE_EXTRA_MACRO; }
      C
      'device_config.h' => %(#ifndef DEVICE_CONFIG_H\n#define DEVICE_CONFIG_H\n#define DEVICE_COUNT 2\n#endif\n),
      'device_extra.h'  => %(#ifndef DEVICE_EXTRA_H\n#define DEVICE_EXTRA_H\n#define DEVICE_EXTRA_MACRO (42)\n#endif\n)
    }
    expect(extracted(tree, 'widget.c')).to contain_exactly(
      '#include "device_config.h"', '#include "device_extra.h"'
    )
  end

  it 'still does not resolve a backslash-continued computed #include on the forced text-scan path' do
    # Same documented fallback limitation as the single-line shape below: no
    # directives-only stream exists in fallback to correlate against at all.
    tree = {
      'widget.c' => <<~C,
        #include "device_config.h"
        #{COMPUTED}
        #if DEVICE_COUNT > 1
        #include \\
          PICK(device_extra)
        #endif
        int w(void) { return 0; }
      C
      'device_config.h' => %(#ifndef DEVICE_CONFIG_H\n#define DEVICE_CONFIG_H\n#define DEVICE_COUNT 2\n#endif\n),
      'device_extra.h'  => %(#ifndef DEVICE_EXTRA_H\n#define DEVICE_EXTRA_H\n#define DEVICE_EXTRA_MACRO (42)\n#endif\n)
    }
    expect(extracted(tree, 'widget.c', fallback: true)).to eq(['#include "device_config.h"'])
  end

  it 'does not resolve a sibling-macro-guarded computed #include on the forced text-scan path' do
    # Documented limitation: fallback has no directives-only stream to correlate
    # against, so a computed #include behind a guard the text scan can't evaluate is
    # left out. The literal sibling header is still found.
    tree = {
      'widget.c' => <<~C,
        #include "device_config.h"
        #{COMPUTED}
        #if DEVICE_COUNT > 1
        #include PICK(device_extra)
        #endif
        int w(void) { return 0; }
      C
      'device_config.h' => %(#ifndef DEVICE_CONFIG_H\n#define DEVICE_CONFIG_H\n#define DEVICE_COUNT 2\n#endif\n),
      'device_extra.h'  => %(#ifndef DEVICE_EXTRA_H\n#define DEVICE_EXTRA_H\n#define DEVICE_EXTRA_MACRO (42)\n#endif\n)
    }
    expect(extracted(tree, 'widget.c', fallback: true)).to eq(['#include "device_config.h"'])
  end

  it 'falls back per file when the directives-only pass cannot resolve an include' do
    # The directives-only tool has no -MG, so an unresolvable #include makes that pass
    # exit non-zero; generate_directives_only_output returns nil and this one file
    # drops to the text-scan path, which still captures the literal directive.
    tree = {
      'missing.c' => %(#include "absent.h"\n#include "present.h"\nint m(void){return 0;}\n),
      'present.h' => %(#ifndef PRESENT_H\n#define PRESENT_H\nint p(void);\n#endif\n)
    }
    result = extracted(tree, 'missing.c')
    expect(result).to include('#include "present.h"')
    expect(result).to include('#include "absent.h"')
  end
end
