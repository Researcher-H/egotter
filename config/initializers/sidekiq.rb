require_relative '../../lib/egotter/sidekiq/run_history'

Sidekiq.logger.level = Logger::DEBUG

database = Rails.env.test? ? 1 : 0

Sidekiq.configure_server do |config|
  config.redis = {url: "redis://#{ENV['REDIS_HOST']}:6379/#{database}"}
  config.server_middleware do |chain|
    chain.add Egotter::Sidekiq::ServerUniqueJob
    chain.add ExpireJob::Middleware
    chain.add Egotter::Sidekiq::TimeoutJob
  end
  config.client_middleware do |chain|
    chain.add Egotter::Sidekiq::ClientUniqueJob, 'server'
  end
end

Sidekiq.configure_client do |config|
  config.redis = {url: "redis://#{ENV['REDIS_HOST']}:6379/#{database}"}
  config.client_middleware do |chain|
    chain.add Egotter::Sidekiq::ClientUniqueJob, 'client'
  end
end
