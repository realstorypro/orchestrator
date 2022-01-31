source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.0.3"

gem "importmap-rails"
gem "jbuilder"
gem "jsonb_accessor"
gem "pg", "~> 1.1"
gem "puma", "~> 5.0"
gem "rails", "~> 7.0.1"
gem "redis", "~> 4.0"
gem 'sidekiq'
gem "sprockets-rails"
gem "stimulus-rails"
gem "turbo-rails"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# API
gem 'customerio'
gem 'httparty'

# AI
gem 'classifier-reborn'

# Errors
gem 'appsignal'

group :development, :test do
  gem "byebug"
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
  gem 'dotenv-rails'
end

group :development do
  gem 'awesome_print'
  gem "web-console"
end

