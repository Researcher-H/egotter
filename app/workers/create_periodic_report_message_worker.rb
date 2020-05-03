class CreatePeriodicReportMessageWorker
  include Sidekiq::Worker
  include Concerns::AirbrakeErrorHandler
  sidekiq_options queue: 'messaging', retry: 0, backtrace: false

  def unique_key(user_id, options = {})
    user_id
  end

  def unique_in
    1.minute
  end

  def after_skip(*args)
    logger.warn "The job execution is skipped."
  end

  # options:
  #   request_id
  #   start_date
  #   end_date
  #   unfriends
  #   unfollowers
  def perform(user_id, options = {})
    user = User.find(user_id)
    unless user.authorized?
      return
    end

    PeriodicReport.periodic_message(user_id, **options.symbolize_keys!).deliver!

  rescue => e
    notify_airbrake(e, user_id: user_id, options: options)
    logger.warn "#{e.class} #{e.message}"
    logger.info e.backtrace.join("\n")
  end
end