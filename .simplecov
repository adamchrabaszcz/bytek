# Coverage settings for bashcov, which CI's coverage step runs (CONTRIBUTING, "Checks").
# bashcov reports every bash script under the repository; the tests themselves (and the bats
# they vendor) are left out.
require "simplecov-cobertura"

SimpleCov.configure do
  skip "/tests/"
  # index.html to browse, coverage.xml (Cobertura) for Codecov; coverage.json is always written.
  formatters [SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::CoberturaFormatter]
end
