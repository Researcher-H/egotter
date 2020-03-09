class SendReceivedMessageWorker
  include Sidekiq::Worker
  include Concerns::AirbrakeErrorHandler
  sidekiq_options queue: 'messaging', retry: 0, backtrace: false

  # options:
  #   text
  #   dm_id
  def perform(sender_uid, options = {})
    send_message_to_slack(sender_uid, options['dm_id'], options['text'])
  rescue => e
    notify_airbrake(e, sender_uid: sender_uid, options: options)
  end

  CONTINUE_NOTIF = 'リムられ通知継続'
  REVIVE_NOTIF = 'リムられ通知復活'
  FOLLOW_NOTIF = 'フォローしたよ'
  RECEIVED_NOTIF = '通知届きました'

  def send_message_to_slack(sender_uid, dm_id, text)
    user = User.find_by(uid: sender_uid)
    screen_name = user ? user.screen_name : (Bot.api_client.user(sender_uid)[:screen_name] rescue sender_uid)

    text = dm_url(screen_name) + "\n" + text
    text = latest_errors(user.id).inspect + "\n" + text if user
    text = error_check(user.id) + "\n" + text if user

    if text.include?(CONTINUE_NOTIF) || text.include?(REVIVE_NOTIF) || text.include?(FOLLOW_NOTIF) || text.include?(RECEIVED_NOTIF)
      SlackClient.continue_notif_messages.send_message(text, title: "`#{screen_name}`")
    else
      SlackClient.received_messages.send_message(text, title: "`#{screen_name}`")
    end
  rescue => e
    logger.warn "Sending a message to slack is failed #{e.inspect}"
    notify_airbrake(e, sender_uid: sender_uid, text: text)
  end

  def dm_url(screen_name)
    "https://twitter.com/direct_messages/create/#{screen_name}"
  end

  def latest_errors(user_id)
    CreatePromptReportLog.error_logs_for_one_day(user_id: user_id, request_id: nil).pluck(:error_class)
  end

  def error_check(user_id)
    CreatePromptReportRequest.new(user_id: user_id).error_check!
    'success'
  rescue => e
    e.class.to_s
  end
end
