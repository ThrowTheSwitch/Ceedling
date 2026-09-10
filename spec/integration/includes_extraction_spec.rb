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
  def extracted(tree, entry, defines: [], fallback: false)
    with_source_tree(tree) do |dir|
      harness = build_includes_harness(dir)
      list = harness.reconcile(
        file: File.join(dir, entry), defines: defines,
        search_paths: [dir], fallback: fallback || !@accurate
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

  it 'currently collapses a subdir user include to its basename' do
    tree = {
      'io.c'      => %(#include <bits/hw.h>\nint io(void){return HW_BIT;}\n),
      'bits/hw.h' => %(#ifndef BITS_HW_H\n#define BITS_HW_H\n#define HW_BIT 1\n#endif\n)
    }
    # Characterization: only a reconciled SYSTEM include gets its as-written spelling
    # restored from the bare pass. A user include is rendered from its basename alone,
    # so `<bits/hw.h>` (project header, categorized user) comes back as `"hw.h"`.
    expect(extracted(tree, 'io.c')).to eq(['#include "hw.h"'])
  end

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
end
