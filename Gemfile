# frozen_string_literal: true

source 'https://rubygems.org'

gem 'jekyll', '~> 4.2'
gem 'nokogiri', '~> 1.11'
gem 'octokit', '~> 4.0'
gem 'pdf-reader', '~> 2.4'
gem 'pdftoimage', '~> 0.1.7'

group :jekyll_plugins do
  gem 'jekyll-github-metadata', '~> 2.13.0'
  gem 'jekyll-minifier', '~> 0.1.10'
  gem 'jekyll-seo-tag', '~> 2.7.1'
  gem 'jekyll-timeago', '~> 0.13.1'
  # jekyll-minifier required a JavaScript runtime
  gem 'therubyracer', '~> 0.12.3'
end

group :development do
  gem 'rubocop', '~> 1.8.1'
  gem 'rubocop-performance', '~> 1.9.2'
end

group :test, :development do
  gem 'rspec', '~> 3.10.0'
end
