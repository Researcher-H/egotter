class UpdateAuthorizedWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'misc', retry: 0, backtrace: false

  def unique_key(user_id, options = {})
    user_id
  end

  def unique_in
    1.minute
  end

  def expire_in
    1.minute
  end

  def timeout_in
    5.seconds
  end

  def after_timeout(*args)
    UpdateAuthorizedWorker.perform_in(retry_in, *args)
  end

  def retry_in
    unique_in + rand(120)
  end

  # options:
  def perform(user_id, options = {})
    user = User.find(user_id)
    t_user = user.api_client.verify_credentials

    user.screen_name = t_user[:screen_name]
    user.save! if user.changed?
  rescue => e
    if AccountStatus.unauthorized?(e)
      user.update!(authorized: false)
    elsif AccountStatus.not_found?(e) || AccountStatus.suspended?(e) || AccountStatus.too_many_requests?(e)
      # Do nothing
    else
      logger.warn "#{e.inspect} user_id=#{user_id} options=#{options.inspect}"
      logger.info e.backtrace.join("\n")
    end
  end
end
