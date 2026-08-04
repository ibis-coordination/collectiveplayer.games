source "https://rubygems.org"

ruby "3.4.4"

# All gems are pessimistically pinned ("~> X.Y") so `bundle update`
# never silently pulls a major. Majors flow in as their own Dependabot
# PR for individual review; the grouped weekly PR only carries
# patch/minor bumps.

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails", "~> 3.5"

# SQLite in development/test; Postgres in production (see database.yml)
gem "sqlite3", "~> 2.9", group: [:development, :test]
gem "pg", "~> 1.5", group: :production

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 8.0"

# ActionCable adapter that uses Postgres NOTIFY/LISTEN instead of Redis
gem "solid_cable", "~> 4.0"

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", "~> 2.12", require: false

# Reduces disk IO in the container by writing tmpfs; used by Kamal
gem "thruster", "~> 0.1", require: false

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails", "~> 2.2"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails", "~> 2.0"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails", "~> 1.3"

# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem.
# Intentionally unversioned — tzinfo-data ships new versions each time IANA
# publishes a timezone update, so pinning it means missing DST/leap-second
# changes.
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", "~> 1.24", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", "~> 1.11", platforms: %i[ mri windows ]

  # Load environment variables from .env [https://github.com/bkeepers/dotenv]
  gem "dotenv-rails", "~> 3.2"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console", "~> 4.3"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara", "~> 3.40"
  gem "capybara-playwright-driver", "~> 0.5"
end
