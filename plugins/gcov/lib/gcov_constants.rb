# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

GCOV_ROOT_NAME                  = 'gcov'.freeze
GCOV_TASK_ROOT                  = GCOV_ROOT_NAME + ':'
GCOV_SYM                        = GCOV_ROOT_NAME.to_sym

GCOV_REPORT_NAMESPACE           = 'report'.freeze
GCOV_REPORT_NAMESPACE_SYM       = GCOV_REPORT_NAMESPACE.to_sym

GCOV_BUILD_PATH                 = File.join(PROJECT_BUILD_ROOT, GCOV_ROOT_NAME)
GCOV_BUILD_OUTPUT_PATH          = File.join(GCOV_BUILD_PATH, "out")
GCOV_RESULTS_PATH               = File.join(GCOV_BUILD_PATH, "results")
GCOV_DEPENDENCIES_PATH          = File.join(GCOV_BUILD_PATH, "dependencies")
GCOV_ARTIFACTS_PATH             = File.join(PROJECT_BUILD_ARTIFACTS_ROOT, GCOV_ROOT_NAME)

GCOV_REPORT_GENERATOR_ARTIFACTS_PATH  = File.join(GCOV_ARTIFACTS_PATH, "ReportGenerator")
GCOV_GCOVR_ARTIFACTS_PATH             = File.join(GCOV_ARTIFACTS_PATH, "gcovr")

GCOV_GCOVR_ARTIFACTS_FILE_HTML        = File.join(GCOV_GCOVR_ARTIFACTS_PATH, "GcovCoverageResults.html")
GCOV_GCOVR_ARTIFACTS_FILE_COBERTURA   = File.join(GCOV_GCOVR_ARTIFACTS_PATH, "GcovCoverageCobertura.xml")
GCOV_GCOVR_ARTIFACTS_FILE_SONARQUBE   = File.join(GCOV_GCOVR_ARTIFACTS_PATH, "GcovCoverageSonarQube.xml")
GCOV_GCOVR_ARTIFACTS_FILE_JSON        = File.join(GCOV_GCOVR_ARTIFACTS_PATH, "GcovCoverage.json")

TOOL_COLLECTION_GCOV_TASKS = {
  :test_compiler  => TOOLS_GCOV_COMPILER,
  :test_assembler => TOOLS_TEST_ASSEMBLER,
  :test_linker    => TOOLS_GCOV_LINKER,
  :test_fixture   => TOOLS_GCOV_FIXTURE
}

# Report Creation Utilities
GCOV_UTILITY_NAME_GCOVR = "gcovr"
GCOV_UTILITY_NAME_REPORT_GENERATOR = "ReportGenerator"
GCOV_UTILITY_NAMES = [GCOV_UTILITY_NAME_GCOVR, GCOV_UTILITY_NAME_REPORT_GENERATOR]

# Report Types
class ReportTypes
  HTML_BASIC = "HtmlBasic"
  HTML_DETAILED = "HtmlDetailed"
  HTML_CHART = "HtmlChart"
  HTML_INLINE = "HtmlInline"
  HTML_INLINE_AZURE = "HtmlInlineAzure"
  HTML_INLINE_AZURE_DARK = "HtmlInlineAzureDark"
  MHTML = "MHtml"
  TEXT = "Text"
  COBERTURA = "Cobertura"
  SONARQUBE = "SonarQube"
  JSON = "JSON"
  BADGES = "Badges"
  CSV_SUMMARY = "CsvSummary"
  LATEX = "Latex"
  LATEX_SUMMARY = "LatexSummary"
  PNG_CHART = "PngChart"
  TEAM_CITY_SUMMARY = "TeamCitySummary"
  LCOV = "lcov"
  XML = "Xml"
  XML_SUMMARY = "XmlSummary"
end
