# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature 'sig'

  check '*.rb'
  # check 'Gemfile'

  library 'set'
  # library 'nokogiri'

  # configure_code_diagnostics(D::Ruby.strict)
  # configure_code_diagnostics(D::Ruby.lenient)
end

target :test do
  signature 'sig'

  check 'spec'

  ignore 'spec/spec_helper.rb'
end
