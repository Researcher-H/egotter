# == Schema Information
#
# Table name: create_prompt_report_requests
#
#  id          :bigint(8)        not null, primary key
#  user_id     :integer          not null
#  finished_at :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_create_prompt_report_requests_on_created_at  (created_at)
#  index_create_prompt_report_requests_on_user_id     (user_id)
#

class CreatePromptReportRequest < ApplicationRecord
  include Concerns::Request::Runnable
  belongs_to :user
  has_many :logs, -> { order(created_at: :asc) }, foreign_key: :request_id, class_name: 'CreatePromptReportLog'

  validates :user_id, presence: true

  def perform!
    raise InvalidToken unless valid_token?

    if twitter_user_not_exist?
      if initialization_started?
        raise TwitterUserNotExist
      else
        send_initialization_message
      end
    end

    raise TooShortRequestInterval if too_short_request_interval?
    raise Unauthorized unless user.authorized?
    raise ReportDisabled unless user.dm_enabled?
    raise TooShortSendInterval unless user.dm_interval_ok?
    raise Inactive unless user.active?(14)
    raise RecordNotFound unless TwitterUser.exists?(uid: user.uid)

    raise Suspended if suspended?
    raise TooManyFriends if too_many_friends?
    raise Blocked if blocked?

    twitter_user = self.twitter_user
    raise TooManyFriends if twitter_user.too_many_friends?(login_user: user)
    raise MaybeImportBatchFailed if twitter_user.no_need_to_import_friendships?

    friend_uids, follower_uids = friend_uids_and_follower_uids
    raise Unauthorized if friend_uids.nil? && follower_uids.nil?

    latest = TwitterUser.new.tap do |user|
      user.friend_uids = friend_uids
      user.follower_uids = follower_uids
    end

    new_unfollower_uids = UnfriendsBuilder::Util.unfollowers(twitter_user, latest)
    raise UnfollowersNotChanged if new_unfollower_uids.none?

    changes = {followers_count: [twitter_user.follower_uids.size, latest.follower_uids.size]}

    last_report = user.latest_prompt_report
    raise MessageNotChanged if last_report && changes == last_report.last_changes

    send_report!(changes, new_unfollower_uids: new_unfollower_uids)
  end

  def send_initialization_message
    DirectMessageRequest.new(internal_client, User::EGOTTER_UID, I18n.t('dm.promptReportNotification.initialization_start')).perform
    DirectMessageRequest.new(User.find_by(uid: User::EGOTTER_UID).api_client.twitter, user.uid, I18n.t('dm.promptReportNotification.search_yourself', screen_name: user.screen_name, url: Rails.application.routes.url_helpers.timeline_url(screen_name: user.screen_name))).perform

    raise InitializationStarted
  rescue Twitter::Error::Forbidden => e
    if e.message == 'You cannot send messages to users you have blocked.'
      CreateBlockedUserWorker.perform_async(user.uid, user.screen_name)
    else
      logger.warn "#{e.class} #{e.message} #{self.inspect}"
      logger.info e.backtrace.join("\n")
    end

    raise InitializationFailed.new(e.message.truncate(100))
  rescue InitializationStarted => e
    raise
  rescue => e
    logger.warn "#{e.class} #{e.message} #{self.inspect}"
    logger.info e.backtrace.join("\n")

    raise InitializationFailed.new(e.message.truncate(100))
  end

  def send_report!(changes, new_unfollower_uids:)
    PromptReport.you_are_removed(user.id, changes_json: changes.to_json, new_unfollower_uids: new_unfollower_uids).deliver
  rescue Twitter::Error::Forbidden => e
    if e.message == 'You cannot send messages to users you have blocked.'
      CreateBlockedUserWorker.perform_async(user.uid, user.screen_name)
    elsif e.message == 'You cannot send messages to users who are not following you.'
    elsif e.message == 'You are sending a Direct Message to users that do not follow you.'
    else
      logger.warn "#{e.class} #{e.message} #{self.inspect} #{changes.inspect}"
      logger.info e.backtrace.join("\n")
    end

    raise DirectMessageNotSent
  rescue => e
    logger.warn "#{e.class} #{e.message} #{self.inspect} #{changes.inspect}"
    logger.info e.backtrace.join("\n")

    raise DirectMessageNotSent.new(e.message.truncate(100))
  end

  def twitter_user
    latest_user = TwitterUser.where('created_at < ?', user.last_access_at).latest_by(uid: user.uid) if user.last_access_at
    latest_user = TwitterUser.latest_by(uid: user.uid) unless latest_user
    latest_user
  end

  private

  def valid_token?
    internal_client.verify_credentials
  rescue Twitter::Error::Unauthorized => e
    if e.message == 'Invalid or expired token.'
      raise Unauthorized
    else
      logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect}"
      logger.info e.backtrace.join("\n")
      raise
    end
  rescue => e
    logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect}"
    logger.info e.backtrace.join("\n")
    raise
  end

  def twitter_user_not_exist?
    !TwitterUser.exists?(uid: user.uid)
  end

  def initialization_started?
    CreatePromptReportLog.where(user_id: user_id).pluck(:error_class).any? {|err| err.include? 'Initialization' }
  end

  INTERVAL = 30.minutes

  def too_short_request_interval?
    self.class.where(user_id: user.id, created_at: INTERVAL.ago..Time.zone.now).
        where.not(id: id).exists?
  end

  def suspended?
    fetch_user[:suspended]
  end

  def too_many_friends?
    TwitterUser.too_many_friends?(fetch_user, login_user: user)
  end

  def blocked?
    if BlockedUser.exists?(uid: fetch_user[:id])
      true
    else
      blocked = client.blocked_ids.include? User::EGOTTER_UID
      CreateBlockedUserWorker.perform_async(fetch_user[:id], fetch_user[:screen_name]) if blocked
      blocked
    end
  rescue => e
    logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect}"
    logger.info e.backtrace.join("\n")
    raise
  end

  def fetch_user
    @fetch_user ||= client.user(user.uid)
  rescue Twitter::Error::Forbidden => e
    if e.message.start_with? 'To protect our users from spam and other malicious activity, this account is temporarily locked.'
      raise Forbidden
    else
      logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect}"
      logger.info e.backtrace.join("\n")
      raise
    end
  rescue => e
    logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect}"
    logger.info e.backtrace.join("\n")
    raise
  end

  def friend_uids_and_follower_uids
    client.friend_ids_and_follower_ids(user.uid)
  rescue => e
    logger.warn "#{self.class}##{__method__} #{e.class} #{e.message} #{self.inspect}"
    logger.info e.backtrace.join("\n")
    raise
  end

  def client
    @client ||= user.api_client
  end

  def internal_client
    @internal_client ||= client.twitter
  end

  class Error < StandardError
  end

  class DeadErrorTellsNoTales < Error
    def initialize(*args)
      super('')
    end
  end

  class TwitterUserNotExist < DeadErrorTellsNoTales
  end

  class InitializationStarted < DeadErrorTellsNoTales
  end

  class InitializationFailed < Error
  end

  class TooShortRequestInterval < DeadErrorTellsNoTales
  end

  class TooShortSendInterval < DeadErrorTellsNoTales
  end

  class InvalidToken < DeadErrorTellsNoTales
  end

  class Unauthorized < DeadErrorTellsNoTales
  end

  class Forbidden < DeadErrorTellsNoTales
  end

  class ReportDisabled < DeadErrorTellsNoTales
  end

  class Inactive < DeadErrorTellsNoTales
  end

  class RecordNotFound < DeadErrorTellsNoTales
  end

  class Suspended < DeadErrorTellsNoTales
  end

  class TooManyFriends < DeadErrorTellsNoTales
  end

  class Blocked < DeadErrorTellsNoTales
  end

  class MaybeImportBatchFailed < DeadErrorTellsNoTales
  end

  class UnfollowersNotChanged < DeadErrorTellsNoTales
  end

  class MessageNotChanged < DeadErrorTellsNoTales
  end

  class DirectMessageNotSent < Error
  end
end
