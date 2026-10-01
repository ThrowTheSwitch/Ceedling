# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/reportinator'
require 'ceedling/plugins/plugin_reportinator'
require 'ceedling/templateinator'
require 'template_render_cases'

# Renders every real report template through the real PluginReportinator pipeline
# and compares byte for byte against output captured from ERB 2.2.0 before ERB was
# removed as a dependency.
#
# The fixtures carry ERB's behavior as committed data rather than as a live
# dependency, which is what lets this equivalence check survive erb's removal and
# keep working on a Ruby that has no erb at all. Treat the fixture bytes as the
# frozen contract. A failure here means rendering changed, not that the fixtures
# need refreshing, and regenerating them would destroy the only reference that
# remains.
describe 'Report template rendering against captured ERB output' do
  def render(template, hash)
    captured = nil
    loginator = double('loginator')
    allow(loginator).to receive(:decorate) { |str, _label| str }
    allow(loginator).to receive(:log) { |output, *_| captured = output }

    reportinator_plugin = PluginReportinator.new(
      {
        plugin_reportinator_helper: nil,
        plugin_manager: nil,
        reportinator: Reportinator.new,
        loginator: loginator,
        templateinator: Templateinator.new
      }
    )
    reportinator_plugin.set_system_objects({ plugin_reportinator: reportinator_plugin })
    reportinator_plugin.run_report( template, hash )

    return captured
  end

  TemplateRenderCases.templates.each_pair do |template_name, template|
    context "the #{template_name} template" do
      TemplateRenderCases.cases.each_pair do |case_name, hash|
        it "renders #{case_name} exactly as ERB did" do
          fixture = File.join( TemplateRenderCases::FIXTURES_PATH, "#{template_name}__#{case_name}.txt" )

          # The gtest-style template mutates the collections it walks, so each render
          # gets its own deep copy rather than one shared across examples.
          output = render( template, Marshal.load( Marshal.dump( hash ) ) )

          expect(output).to eq( File.binread( fixture ) )
        end
      end
    end
  end
end
