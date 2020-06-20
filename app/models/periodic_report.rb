# == Schema Information
#
# Table name: periodic_reports
#
#  id         :bigint(8)        not null, primary key
#  user_id    :integer          not null
#  read_at    :datetime
#  token      :string(191)      not null
#  message_id :string(191)      not null
#  message    :string(191)      default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_periodic_reports_on_created_at              (created_at)
#  index_periodic_reports_on_token                   (token) UNIQUE
#  index_periodic_reports_on_user_id                 (user_id)
#  index_periodic_reports_on_user_id_and_created_at  (user_id,created_at)
#

class PeriodicReport < ApplicationRecord
  include Concerns::Report::HasToken
  include Concerns::Report::Readable

  belongs_to :user

  attr_accessor :dont_send_remind_message

  def deliver!
    dm = send_direct_message
    update!(message_id: dm.id, message: dm.truncated_message)
  end

  # Keep a minimum of files in the cache to avoid "NameError: undefined local variable or method"
  TEMPLATES = {
      removed: Rails.root.join('app/views/periodic_reports/removed.ja.text.erb').read,
      not_removed: Rails.root.join('app/views/periodic_reports/not_removed.ja.text.erb').read
  }

  class << self
    # options:
    #   request_id
    #   start_date (required)
    #   end_date (required)
    #   first_friends_count
    #   first_followers_count
    #   last_friends_count
    #   last_followers_count
    #   latest_friends_count
    #   latest_followers_count
    #   unfriends
    #   unfriends_count
    #   unfollowers (required)
    #   unfollowers_count
    #   total_unfollowers
    #   worker_context
    def periodic_message(user_id, options = {})
      user = User.find(user_id)
      start_date = extract_date(:start_date, options)
      end_date = extract_date(:end_date, options)

      unfollowers = options[:unfollowers]
      total_unfollowers = options[:total_unfollowers]
      template = unfollowers.empty? ? TEMPLATES[:not_removed] : TEMPLATES[:removed]

      token = generate_token
      url_options = {token: token, medium: 'dm', type: 'periodic', via: 'periodic_report', og_tag: 'false'}

      I18n.backend.store_translations :ja, persons: {one: '%{count}人', other: '%{count}人'}

      message = ERB.new(template).result_with_hash(
          user: user,
          start_date: start_date,
          end_date: end_date,
          date_range: date_helper.time_ago_in_words(start_date),
          removed_by: unfollowers.size == 1 ? unfollowers.first : I18n.t(:persons, count: options[:unfollowers_count]),
          aggregation_period: calc_aggregation_period(start_date, end_date),
          period_name: pick_period_name,
          followers_count_change: calc_followers_count_change(options[:first_followers_count], options[:last_followers_count], options[:latest_followers_count]),
          first_friends_count: options[:first_friends_count],
          first_followers_count: options[:first_followers_count],
          last_friends_count: options[:last_friends_count],
          last_followers_count: options[:last_followers_count],
          unfriends_count: options[:unfriends_count],
          unfollowers_count: options[:unfollowers_count],
          unfriends: options[:unfriends],
          unfollowers: unfollowers,
          unfollower_urls: unfollowers.map { |name| "#{name} #{profile_url(name, url_options)}" },
          total_unfollowers: total_unfollowers,
          total_unfollower_urls: total_unfollowers.map { |name| "#{name} #{profile_url(name, url_options)}" },
          regular_subscription: !StopPeriodicReportRequest.exists?(user_id: user.id),
          request_id_text: request_id_text(user, options[:request_id], options[:worker_context]),
          timeline_url: timeline_url(user, url_options),
          settings_url: settings_url(url_options),
      )

      new(user: user, message: message, token: token)
    end

    def remind_reply_message
      template = Rails.root.join('app/views/periodic_reports/remind_reply.ja.text.erb')
      url_params = campaign_params('remind_reply').merge(og_tag: false)
      message = ERB.new(template.read).result_with_hash(
          url: support_url(url_params),
      )

      new(user: nil, message: message, token: nil)
    end

    def remind_access_message
      template = Rails.root.join('app/views/periodic_reports/remind_access.ja.text.erb')
      url_params = campaign_params('remind_access').merge(share_dialog: 1, follow_dialog: 1, og_tag: false)
      message = ERB.new(template.read).result_with_hash(
          url: root_url(url_params),
      )

      new(user: nil, message: message, token: nil)
    end

    def allotted_messages_will_expire_message(user_id)
      user = User.find(user_id)
      template = Rails.root.join('app/views/periodic_reports/allotted_messages_will_expire.ja.text.erb')

      ttl = GlobalDirectMessageReceivedFlag.new.remaining(user.uid)
      if ttl.nil? || ttl <= 0
        logger.warn "#{self}##{__method__} remaining ttl is nil or less than 0 user_id=#{user_id}"
        ttl = 5.minutes + rand(300)
      end

      url_params = campaign_params('will_expire').merge(og_tag: false)

      message = ERB.new(template.read).result_with_hash(
          interval: date_helper.distance_of_time_in_words(ttl),
          url: support_url(url_params),
      )

      new(user: user, message: message, token: generate_token, dont_send_remind_message: true)
    end

    def sending_soft_limited_message(user_id)
      template = Rails.root.join('app/views/periodic_reports/sending_soft_limited.ja.text.erb')
      url_params = campaign_params('soft_limited').merge(og_tag: false)
      message = ERB.new(template.read).result_with_hash(
          url: support_url(url_params),
      )

      new(user: User.find(user_id), message: message, token: generate_token, dont_send_remind_message: true)
    end

    def web_access_hard_limited_message(user_id)
      user = User.find(user_id)
      template = Rails.root.join('app/views/periodic_reports/web_access_hard_limited.ja.text.erb')
      url_params = campaign_params('web_access_hard_limited').merge(og_tag: false)
      message = ERB.new(template.read).result_with_hash(
          access_day: user.access_days.last,
          url: root_url(url_params),
      )

      new(user: user, message: message, token: generate_token, dont_send_remind_message: true)
    end

    def interval_too_short_message(user_id)
      template = Rails.root.join('app/views/periodic_reports/interval_too_short.ja.text.erb')
      message = ERB.new(template.read).result_with_hash(
          interval: I18n.t('datetime.distance_in_words.x_minutes', count: CreatePeriodicReportRequest::SHORT_INTERVAL / 1.minute)
      )

      new(user: User.find(user_id), message: message, token: generate_token)
    end

    def scheduled_job_exists_message(user_id, jid)
      scheduled_job = CreatePeriodicReportRequest::ScheduledJob.find_by(jid: jid)

      if scheduled_job
        template = Rails.root.join('app/views/periodic_reports/scheduled_job_exists.ja.text.erb')
        message = ERB.new(template.read).result_with_hash(
            interval: date_helper.distance_of_time_in_words(CreatePeriodicReportRequest::SHORT_INTERVAL),
            sent_at: date_helper.time_ago_in_words(scheduled_job.perform_at)
        )

        new(user: User.find(user_id), message: message, token: generate_token)
      else
        logger.warn "#{self}##{__method__} scheduled job not found user_id=#{user_id} jid=#{jid}"
        interval_too_short_message(user_id)
      end
    end

    def scheduled_job_created_message(user_id, jid)
      scheduled_job = CreatePeriodicReportRequest::ScheduledJob.find_by(jid: jid)

      if scheduled_job
        template = Rails.root.join('app/views/periodic_reports/scheduled_job_created.ja.text.erb')
        message = ERB.new(template.read).result_with_hash(
            interval: date_helper.distance_of_time_in_words(CreatePeriodicReportRequest::SHORT_INTERVAL),
            sent_at: date_helper.time_ago_in_words(scheduled_job.perform_at)
        )

        new(user: User.find(user_id), message: message, token: generate_token)
      else
        logger.warn "#{self}##{__method__} scheduled job not found user_id=#{user_id} jid=#{jid}"
        interval_too_short_message(user_id)
      end
    end

    def request_interval_too_short_message(user_id)
      template = Rails.root.join('app/views/periodic_reports/request_interval_too_short.ja.text.erb')
      message = ERB.new(template.read).result_with_hash(
          interval: I18n.t('datetime.distance_in_words.x_seconds', count: CreatePeriodicReportWorker::UNIQUE_IN)
      )

      new(user: User.find(user_id), message: message, token: generate_token)
    end

    def cannot_send_messages_message
      template = Rails.root.join('app/views/periodic_reports/cannot_send_messages.ja.text.erb')
      message = ERB.new(template.read).result

      new(user: nil, message: message, token: nil)
    end

    def unauthorized_message
      template = Rails.root.join('app/views/periodic_reports/unauthorized.ja.text.erb')
      message = ERB.new(template.read).result_with_hash(
          sign_in_url: sign_in_url(via: 'unauthorized_message', og_tag: 'false'),
          sign_in_and_follow_url: sign_in_url(follow: true, via: 'unauthorized_message', og_tag: 'false'),
      )

      new(user: nil, message: message, token: nil)
    end

    def unregistered_message
      template = Rails.root.join('app/views/periodic_reports/unregistered.ja.text.erb')
      message = ERB.new(template.read).result_with_hash(
          sign_in_url: sign_in_url(via: 'unregistered_message', og_tag: 'false'),
          sign_in_and_follow_url: sign_in_url(follow: true, via: 'unregistered_message', og_tag: 'false'),
      )

      new(user: nil, message: message, token: nil)
    end

    def not_following_message
      template = Rails.root.join('app/views/periodic_reports/not_following.ja.text.erb')
      message = ERB.new(template.read).result_with_hash(
          url: sign_in_url(force_login: true, follow: true, via: 'not_following_message', og_tag: 'false')
      )

      new(user: nil, message: message, token: nil)
    end

    def permission_level_not_enough_message
      template = Rails.root.join('app/views/periodic_reports/permission_level_not_enough.ja.text.erb')
      message = ERB.new(template.read).result_with_hash(
          url: sign_in_url(force_login: true, via: 'permission_level_not_enough_message', og_tag: 'false')
      )

      new(user: nil, message: message, token: nil)
    end

    def restart_requested_message
      template = Rails.root.join('app/views/periodic_reports/restart_requested.ja.text.erb')
      message = ERB.new(template.read).result

      new(user: nil, message: message, token: nil)
    end

    def stop_requested_message
      template = Rails.root.join('app/views/periodic_reports/stop_requested.ja.text.erb')
      message = ERB.new(template.read).result

      new(user: nil, message: message, token: nil)
    end

    def periodic_push_message(user_id, options = {})
      user = User.find(user_id)
      start_date = extract_date(:start_date, options)
      end_date = extract_date(:end_date, options)

      unfollowers = options[:unfollowers]
      if unfollowers.any?
        template = Rails.root.join('app/views/periodic_reports/removed_push.ja.text.erb')
      else
        template = Rails.root.join('app/views/periodic_reports/not_removed_push.ja.text.erb')
      end

      token = generate_token
      url_options = {token: token, medium: 'dm', type: 'periodic', via: 'periodic_report', og_tag: 'false'}

      I18n.backend.store_translations :ja, persons: {one: '%{count}人', other: '%{count}人'}

      ERB.new(template.read).result_with_hash(
          user: user,
          start_date: start_date,
          end_date: end_date,
          date_range: date_helper.time_ago_in_words(start_date),
          removed_by: unfollowers.size == 1 ? unfollowers.first : I18n.t(:persons, count: options[:unfollowers_count]),
          period_name: pick_period_name,
          unfriends: options[:unfriends],
          unfollowers: unfollowers,
          timeline_url: timeline_url(user, url_options),
      )
    end

    def pick_period_name
      time = Time.zone.now.in_time_zone('Tokyo')
      case time.hour
      when 0..5
        I18n.t('activerecord.attributes.periodic_report.period_name.midnight')
      when 6..10
        I18n.t('activerecord.attributes.periodic_report.period_name.morning')
      when 11..14
        I18n.t('activerecord.attributes.periodic_report.period_name.noon')
      when 15..19
        I18n.t('activerecord.attributes.periodic_report.period_name.evening')
      when 20..23
        I18n.t('activerecord.attributes.periodic_report.period_name.night')
      else
        I18n.t('activerecord.attributes.periodic_report.period_name.irregular')
      end
    end

    def calc_aggregation_period(start_date, end_date)
      "#{I18n.l(start_date.in_time_zone('Tokyo'), format: :periodic_report_short)} - #{I18n.l(end_date.in_time_zone('Tokyo'), format: :periodic_report_short)}"
    end

    def calc_followers_count_change(first_count, last_count, latest_count)
      if first_count && last_count
        "#{first_count} - #{last_count}"
      else
        latest_count.to_s
      end
    end

    def profile_url(screen_name, options)
      super(screen_name, campaign_params('report_profile').merge(options))
    end

    def timeline_url(user, options)
      super(user, campaign_params('report_timeline').merge(options))
    end

    def request_id_text(user, request_id, worker_context)
      setting = user.periodic_report_setting
      access_day = user.access_days.last

      [
          request_id.to_i % 1000,
          (TwitterUser.latest_by(uid: user.uid)&.id || 999) % 1000,
          remaining_ttl_text(GlobalDirectMessageReceivedFlag.new.remaining(user.uid)),
          setting.period_flags,
          access_day ? access_day.short_date : '0000',
          worker_context_text(worker_context)
      ].join('-')

    rescue => e
      logger.warn "#{self}##{__method__} #{e.inspect} user_id=#{user.id}"
      "#{rand(10000)}-er"
    end

    def remaining_ttl_text(ttl)
      if ttl.nil?
        '0'
      elsif ttl < 1.hour
        "#{(ttl / 1.minute).to_i}m"
      else
        "#{(ttl / 1.hour).to_i}h"
      end
    end

    def worker_context_text(context)
      case context
      when CreateUserRequestedPeriodicReportWorker.name
        'u'
      when CreateAndroidRequestedPeriodicReportWorker.name
        'a'
      when CreateEgotterRequestedPeriodicReportWorker.name
        'e'
      when CreatePeriodicReportWorker.name
        'b'
      else
        'un'
      end
    end

    def extract_date(key, options)
      date = options[key]
      date = Time.zone.parse(date) if date.class == String
      date
    end

    def campaign_params(name)
      {utm_source: name, utm_medium: 'dm', utm_campaign: "#{name}_#{I18n.l(Time.zone.now, format: :date_hyphen)}"}
    end

    def date_helper
      @date_helper ||= Class.new { include ActionView::Helpers::DateHelper }.new
    end
  end

  def send_direct_message
    event = self.class.build_direct_message_event(report_recipient.uid, message)
    dm = report_sender.api_client.create_direct_message_event(event: event)

    send_remind_message_if_needed

    dm
  end

  def send_remind_message_if_needed
    if send_remind_reply_message?
      send_remind_reply_message
    elsif send_remind_access_message?
      send_remind_access_message
    end
  end

  REMAINING_TTL_SOFT_LIMIT = 12.hours
  REMAINING_TTL_HARD_LIMIT = 3.hours

  def send_remind_reply_message?
    return false if dont_send_remind_message

    if self.class.messages_allotted?(user)
      self.class.allotted_messages_will_expire_soon?(user)
    else
      true
    end
  end

  ACCESS_DAYS_SOFT_LIMIT = 5.days
  ACCESS_DAYS_HARD_LIMIT = 7.days

  def send_remind_access_message?
    return false if dont_send_remind_message

    if self.class.messages_allotted?(user)
      self.class.web_access_soft_limited?(user)
    else
      true
    end
  end

  def send_remind_reply_message
    send_remind_message(self.class.remind_reply_message.message)
  end

  def send_remind_access_message
    send_remind_message(self.class.remind_access_message.message)
  end

  def send_remind_message(message)
    event = self.class.build_direct_message_event(user.uid, message)
    User.egotter.api_client.create_direct_message_event(event: event)
  rescue => e
    if DirectMessageStatus.cannot_send_messages?(e)
      # Do nothing
    else
      logger.warn "#{self}##{__method__} sending remind message is failed #{e.inspect} user_id=#{user_id}"
    end
  end

  class << self
    # options:
    #   unsubscribe
    def build_direct_message_event(uid, message, options = {})
      quick_replies = options[:unsubscribe] ? UNSUBSCRIBE_QUICK_REPLY_OPTIONS : DEFAULT_QUICK_REPLY_OPTIONS

      {
          type: 'message_create',
          message_create: {
              target: {recipient_id: uid},
              message_data: {
                  text: message,
                  quick_reply: {
                      type: 'options',
                      options: quick_replies
                  }
              }
          }
      }
    end

    def allotted_messages_will_expire_soon?(user)
      remaining_ttl = GlobalDirectMessageReceivedFlag.new.remaining(user.uid)
      remaining_ttl && remaining_ttl < REMAINING_TTL_HARD_LIMIT
    end

    def allotted_messages_left?(user, count: 4)
      GlobalSendDirectMessageCountByUser.new.count(user.uid) <= count
    end

    def messages_allotted?(user)
      GlobalDirectMessageReceivedFlag.new.received?(user.uid)
    end

    def web_access_soft_limited?(user)
      access_day = user.access_days.last
      access_day && access_day.date < ACCESS_DAYS_SOFT_LIMIT.ago
    end

    def web_access_hard_limited?(user)
      access_day = user.access_days.last
      access_day && access_day.date < ACCESS_DAYS_HARD_LIMIT.ago
    end
  end

  def report_sender
    self.class.messages_allotted?(user) ? User.egotter : user
  end

  def report_recipient
    self.class.messages_allotted?(user) ? user : User.egotter
  end

  DEFAULT_QUICK_REPLY_OPTIONS = [
      {
          label: I18n.t('quick_replies.prompt_reports.label1'),
          description: I18n.t('quick_replies.prompt_reports.description1')
      },
      {
          label: I18n.t('quick_replies.prompt_reports.label3'),
          description: I18n.t('quick_replies.prompt_reports.description3')
      },
      {
          label: I18n.t('quick_replies.prompt_reports.label5'),
          description: I18n.t('quick_replies.prompt_reports.description5')
      }
  ]

  UNSUBSCRIBE_QUICK_REPLY_OPTIONS = [
      {
          label: I18n.t('quick_replies.prompt_reports.label4'),
          description: I18n.t('quick_replies.prompt_reports.description4')
      },
      {
          label: I18n.t('quick_replies.prompt_reports.label3'),
          description: I18n.t('quick_replies.prompt_reports.description3')
      }
  ]

  module UrlHelpers
    def method_missing(method, *args, &block)
      if method.to_s.end_with?('_url')
        Rails.application.routes.url_helpers.send(method, *args, &block)
      else
        super
      end
    end
  end
  extend UrlHelpers
end
