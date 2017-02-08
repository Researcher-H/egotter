require 'active_support/concern'

module Concerns::TwitterUser::Utils
  extend ActiveSupport::Concern

  class_methods do
    def latest(uid)
      order(created_at: :desc).find_by(uid: uid)
    end

    def till(time)
      where('created_at < ?', time)
    end

    def many?(uid)
      where(uid: uid).size >= 2
    end

    def with_friends
      where.not(friends_size: 0, followers_size: 0)
    end
  end

  DEFAULT_SECONDS = Rails.configuration.x.constants['twitter_user_recently_created']

  included do
  end

  def client
    @_client ||= (User.exists?(uid: uid) ? User.find_by(uid: uid).api_client : Bot.api_client)
  end

  def friendless?
    friends_size == 0 && followers_size == 0
  end

  def friend_uids
    new_record? ? friendships.map(&:friend_uid) : friendships.pluck(:friend_uid)
  end

  def follower_uids
    new_record? ? followerships.map(&:follower_uid) : followerships.pluck(:follower_uid)
  end

  def fresh?(attr = :updated_at, seconds: DEFAULT_SECONDS)
    Time.zone.now - send(attr) < seconds
  end
end
