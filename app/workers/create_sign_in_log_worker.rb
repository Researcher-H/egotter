# TODO Remove later
class CreateSignInLogWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'logging', retry: 0, backtrace: false

  def perform(attrs)
    SignInLog.create!(attrs)
  rescue => e
    logger.warn "#{e.class}: #{e.message} #{attrs.inspect}"
  end
end
