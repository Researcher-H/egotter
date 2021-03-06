class SendReceivedMessageWorker
  include Sidekiq::Worker
  include AirbrakeErrorHandler
  sidekiq_options queue: 'messaging', retry: 0, backtrace: false

  # options:
  #   text
  #   dm_id
  def perform(sender_uid, options = {})
    return if static_message?(options['text'])
    send_message_to_slack(sender_uid, options['text'])
  rescue => e
    notify_airbrake(e, sender_uid: sender_uid, options: options)
  end

  QUICK_REPLIES = [
      /\A【?#{I18n.t('quick_replies.continue.label')}】?\z/,
      /\A【?#{I18n.t('quick_replies.revive.label')}】?\z/,
      /\A【?#{I18n.t('quick_replies.followed.label')}】?\z/,
      /\A【?#{I18n.t('quick_replies.prompt_reports.label1')}】?\z/,
      /\A【?#{I18n.t('quick_replies.prompt_reports.label2')}】?\z/,
      /\A【?#{I18n.t('quick_replies.welcome_messages.label1')}】?\z/,
      /\A【?#{I18n.t('quick_replies.welcome_messages.label2')}】?\z/,
      /\A【?#{I18n.t('quick_replies.search_reports.label1')}】?\z/,
      /\A【?#{I18n.t('quick_replies.search_reports.label2')}】?\z/,
  ]

  def static_message?(text)
    text == I18n.t('quick_replies.prompt_reports.label1') ||
        text == I18n.t('quick_replies.prompt_reports.label2') ||
        text == I18n.t('quick_replies.prompt_reports.label3') ||
        text == I18n.t('quick_replies.prompt_reports.label4') ||
        text == I18n.t('quick_replies.prompt_reports.label5') ||
        text.match?(PeriodicReportConcern::SEND_NOW_REGEXP) ||
        text.match?(PeriodicReportConcern::STOP_NOW_REGEXP) ||
        text.match?(PeriodicReportConcern::RESTART_REGEXP) ||
        text.match?(PeriodicReportConcern::RECEIVED_REGEXP) ||
        text.match?(PeriodicReportConcern::CONTINUE_EXACT_REGEXP) ||
        QUICK_REPLIES.any? { |regexp| regexp.match?(text) } ||
        text.match?(/\Aリムられ通知(\s|　)*(送信|受信|継続|今すぐ)?\z/) ||
        text == 'リムられ' ||
        text == '通知' ||
        text == '再開' ||
        text == '継続' ||
        text == '今すぐ' ||
        text == 'あ' ||
        text == 'は' ||
        text == 'り'
  end

  def send_message_to_slack(sender_uid, text)
    screen_name = fetch_screen_name(sender_uid)
    text = dm_url(screen_name) + "\n" + text
    SlackClient.received_messages.send_message(text, title: "`#{screen_name}` `#{sender_uid}`")

    if recently_tweets_deleted_user?(sender_uid)
      SlackClient.delete_tweets.send_message(text, title: "`#{screen_name}` `#{sender_uid}`")
    end
  rescue => e
    logger.warn "Sending a message to slack is failed #{e.inspect}"
    notify_airbrake(e, sender_uid: sender_uid, text: text)
  end

  def recently_tweets_deleted_user?(uid)
    (user = User.find_by(uid: uid)) && DeleteTweetsRequest.order(created_at: :desc).limit(10).pluck(:user_id).include?(user.id)
  end

  def fetch_screen_name(uid)
    user = User.find_by(uid: uid)
    user ? user.screen_name : (Bot.api_client.user(uid)[:screen_name] rescue uid)
  end

  def dm_url(screen_name)
    "https://twitter.com/direct_messages/create/#{screen_name}"
  end
end
