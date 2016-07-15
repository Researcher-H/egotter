class BackgroundSearchWorker
  include Sidekiq::Worker
  sidekiq_options queue: :egotter, retry: false, backtrace: false

  # This worker is called after strict validation for uid in searches_controller,
  # so you don't need to do that in this worker.
  def perform(values)
    user_id = values['user_id'].to_i
    uid = values['uid'].to_i
    screen_name = values['screen_name']
    without_friends = values['without_friends']
    client = (User.exists?(user_id) ? User.find(user_id).api_client : Bot.api_client)
    log_attrs = {
      user_id: user_id,
      uid: uid,
      screen_name: screen_name,
      bot_uid: client.uid
    }

    if (existing_tu = TwitterUser.latest(uid, user_id)).present? && existing_tu.recently_created?
      existing_tu.search_and_touch
      create_success_log(
        "This worker doesn't create TwitterUser because recently created record exists.",
        {call_count: client.call_count}.merge(log_attrs)
      )
      return
    end

    build_options = {
      user_id: user_id,
      egotter_context: 'search',
      build_relation: true,
      without_friends: without_friends
    }
    new_tu = TwitterUser.build(client, uid, build_options)
    if new_tu.save_with_bulk_insert
      new_tu.search_and_touch
      create_success_log(
        'This worker creates a new record of TwitterUser.',
        {call_count: client.call_count}.merge(log_attrs)
      )

      if (user = User.find_by(uid: uid)).present? && user_id != user.id
        BackgroundNotificationWorker.perform_async(user.id, BackgroundNotificationWorker::SEARCH)
      end
      return
    end

    # Egotter needs at least one TwitterUser record to show search result,
    # so this branch should not be executed if TwitterUser is not existed.
    if existing_tu.present?
      existing_tu.search_and_touch
      create_success_log(
        "This worker doesn't save new TwitterUser because existing one is the same as new one.",
        {call_count: client.call_count}.merge(log_attrs)
      )
      return
    end

    create_failed_log(
      BackgroundSearchLog::SomethingError::MESSAGE,
      "This worker doesn't save new TwitterUser because of #{new_tu.errors.full_messages.join(', ')}.",
      {call_count: client.call_count}.merge(log_attrs)
    )
  rescue Twitter::Error::TooManyRequests => e
    create_failed_log(
      BackgroundSearchLog::TooManyRequests::MESSAGE, '',
      {call_count: client.call_count}.merge(log_attrs)
    )
  rescue Twitter::Error::Unauthorized => e
    create_failed_log(
      BackgroundSearchLog::Unauthorized::MESSAGE, '',
      {call_count: client.call_count}.merge(log_attrs)
    )
  rescue => e
    create_failed_log(
      BackgroundSearchLog::SomethingError::MESSAGE, "#{e.class} #{e.message}",
      {call_count: client.call_count}.merge(log_attrs)
    )
  end

  def create_success_log(message, attrs)
    BackgroundSearchLog.create!(
      user_id:     attrs[:user_id],
      uid:         attrs[:uid],
      screen_name: attrs[:screen_name],
      bot_uid:     attrs[:bot_uid],
      status:      true,
      reason:      '',
      message:     message,
      call_count:  attrs[:call_count]
    )
  rescue => e
    logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{attrs.inspect}"
  end

  def create_failed_log(reason, message, attrs)
    BackgroundSearchLog.create!(
      user_id:     attrs[:user_id],
      uid:         attrs[:uid],
      screen_name: attrs[:screen_name],
      bot_uid:     attrs[:bot_uid],
      status:      false,
      reason:      reason,
      message:     message,
      call_count:  attrs[:call_count]
    )
  rescue => e
    logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{reason} #{message} #{attrs.inspect}"
  end
end
