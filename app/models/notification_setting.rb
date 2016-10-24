# == Schema Information
#
# Table name: notification_settings
#
#  id             :integer          not null, primary key
#  email          :boolean          default(TRUE), not null
#  dm             :boolean          default(TRUE), not null
#  news           :boolean          default(TRUE), not null
#  search         :boolean          default(TRUE), not null
#  last_email_at  :datetime         not null
#  last_dm_at     :datetime         not null
#  last_news_at   :datetime         not null
#  last_search_at :datetime         not null
#  from_id        :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_notification_settings_on_from_id  (from_id)
#

class NotificationSetting < ActiveRecord::Base
  belongs_to :user

  SEND_EMAIL_INTERVAL = 1.day

  def can_send_email?
    email? && last_email_at.present? && last_email_at < SEND_EMAIL_INTERVAL.ago
  end

  def email_reset_at
    last_email_at + SEND_EMAIL_INTERVAL
  end

  SEND_DM_INTERVAL = 1.day

  def can_send_dm?
    dm? && last_dm_at.present? && last_dm_at < SEND_DM_INTERVAL.ago
  end

  def dm_reset_at
    last_dm_at + SEND_DM_INTERVAL
  end

  SEND_NEWS_INTERVAL = 1.day

  def can_send_news?
    news? && last_news_at.present? && last_news_at < SEND_NEWS_INTERVAL.ago
  end

  def news_reset_at
    last_news_at + SEND_NEWS_INTERVAL
  end

  SEND_SEARCH_INTERVAL = Rails.env.production? ? 60.minutes : 1.minutes

  def can_send_search?
    search? && last_search_at.present? && last_search_at < SEND_SEARCH_INTERVAL.ago
  end

  def search_reset_at
    last_search_at + SEND_SEARCH_INTERVAL
  end

  def can_send?(type)
    case type
      when :search then can_send_search?
      when :update then can_send_dm?
      else raise "#{self.class}##{__method__}: #{type} is not permitted."
    end
  end
end
