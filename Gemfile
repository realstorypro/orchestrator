source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.0.3"

gem "rails", "~> 7.0.1"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", "~> 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "jsonb_accessor"
gem "redis", "~> 4.0"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# API
gem 'customerio'
gem 'httparty'


# AI
gem 'classifier-reborn'

group :development, :test do
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
  gem "byebug"
  gem 'dotenv-rails'
end

group :development do
  gem "web-console"
  gem 'awesome_print'
end

