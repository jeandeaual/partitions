# frozen_string_literal: true

source 'https://rubygems.org'

gem 'jekyll', '~> 4.2'
gem 'nokogiri', '~> 1.12'
gem 'octokit', '~> 4.0'
gem 'pdf-reader', '~> 2.4'
gem 'pdftoimage', '~> 0.1.7'

group :jekyll_plugins do
  gem 'jekyll-github-metadata', '~> 2.13.0'
  gem 'jekyll-minifier', '~> 0.1.10'
  gem 'jekyll-seo-tag', '~> 2.7.1'
  # jekyll-minifier requires a JavaScript runtime
  gem 'mini_racer', '~> 0.5'
end

group :development do
  gem 'rbs', '~> 1.7'
  gem 'rubocop', '~> 1.23'
  gem 'rubocop-performance', '~> 1.12'
  # For jekyll serve
  gem 'webrick', '~> 1.7'
  gem 'steep', '~> 0.47'
  gem 'typeprof', '~> 0.20'
end

group :test, :development do
  gem 'rspec', '~> 3.10.0'
end
