class FollowEgotterWorker
  include Sidekiq::Worker
  include Concerns::WorkerUtils
  sidekiq_options queue: self, retry: 0, backtrace: false

  def perform(user_id)
    user = User.find(user_id)
    client = user.api_client
    if user.uid.to_i != User::EGOTTER_UID && !client.friendship?(user.uid.to_i, User::EGOTTER_UID)
      client.follow!(User::EGOTTER_UID)
    end

  rescue Twitter::Error::Unauthorized => e
    handle_unauthorized_exception(e, user_id: user_id)
  rescue Twitter::Error::Forbidden => e
    handle_forbidden_exception(e, user_id)

    if e.message == FORBIDDEN_MESSAGES[2] # You are unable to follow more people ...
      logger.warn "I will sleep. Bye! #{user_id}"
      sleep 1.hour
      logger.warn "Good morning. I will retry. #{user_id}"
      retry
    end
  rescue => e
    logger.warn "#{e.class} #{e.message} #{user_id}"
  end
end
