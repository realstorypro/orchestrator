Rails.application.routes.draw do
  # Sidekiq
  require 'sidekiq/web'

  if Rails.env.production?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      sidekiq_username = ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_USERNAME'])
      sidekiq_password = ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_PASSWORD'])

      passed_username = ::Digest::SHA256.hexdigest(username)
      passed_password = ::Digest::SHA256.hexdigest(password)

      ActiveSupport::SecurityUtils.secure_compare(passed_username, sidekiq_username) &
        ActiveSupport::SecurityUtils.secure_compare(passed_password, sidekiq_password)
    end
  end

  mount Sidekiq::Web => '/sidekiq'
end
