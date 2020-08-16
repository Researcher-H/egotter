class SearchCountLimitation

  SIGN_IN_BONUS = Rails.configuration.x.constants['search_count_limitation']['sign_in_bonus']
  SHARING_BONUS = Rails.configuration.x.constants['search_count_limitation']['sharing_bonus']
  PERIODIC_TWEET_BONUS = Rails.configuration.x.constants['search_count_limitation']['periodic_tweet_bonus']
  ANONYMOUS = Rails.configuration.x.constants['search_count_limitation']['anonymous']
  BASIC_PLAN = Rails.configuration.x.constants['search_count_limitation']['basic_plan']

  SEARCH_COUNT_PERIOD = 1.day.to_i

  class << self
    def max_count(user)
      count = ANONYMOUS

      if user
        count += SIGN_IN_BONUS
      end

      if user&.has_valid_subscription?
        count = user.purchased_search_count
      end

      if user && user.sharing_count > 0
        count += user.sharing_count * current_sharing_bonus(user)
      end

      if user
        count += user.valid_coupons_search_count
      end

      if user && CreatePeriodicTweetRequest.exists?(user_id: user.id)
        count += PERIODIC_TWEET_BONUS
      end

      count
    end

    def remaining_count(user: nil, session_id: nil)
      [0, max_count(user) - current_count(user: user, session_id: session_id)].max
    rescue => e
      Rails.logger.warn "##{__method__} Maybe invalid session_id class=#{session_id.class} inspect=#{session_id.inspect}"
      raise
    end

    def count_remaining?(user: nil, session_id: nil)
      remaining_count(user: user, session_id: session_id) >= 1
    end

    def where_condition(user: nil, session_id: nil)
      condition =
          if user
            {user_id: user.id}
          elsif session_id
            {session_id: session_id}
          else
            raise
          end
      condition.merge(created_at: SEARCH_COUNT_PERIOD.seconds.ago..Time.zone.now)
    end

    def current_count(user: nil, session_id: nil)
      # The cause of "ActionView::Template::Error (can't quote Hash)" is invalid session_id.
      # e.g. {"public_id"=>"hash string"}
      SearchHistory.where(where_condition(user: user, session_id: session_id)).size
    end

    def search_count_reset_in(user: nil, session_id: nil)
      record = SearchHistory.order(created_at: :asc).find_by(where_condition(user: user, session_id: session_id))
      record ? [0, (record.created_at + SEARCH_COUNT_PERIOD.seconds - Time.zone.now).to_i].max : 0
    end
    alias count_reset_in search_count_reset_in

    def current_sharing_bonus(user)
      if user&.authorized?
        followers = TwitterUser.latest_by(uid: user.uid)&.followers_count
        followers = user.api_client.user(user.uid)[:followers_count] unless followers
      else
        followers = 0
      end

      case followers
      when 0..1000 then SHARING_BONUS
      when 1001..2000 then SHARING_BONUS + 1
      when 2001..5000 then SHARING_BONUS + 2
      else SHARING_BONUS + 3
      end
    rescue => e
      Rails.logger.warn "##{__method__} #{e.inspect} user_id=#{user&.id}"
      Rails.logger.info e.backtrace.join("\n")
      SHARING_BONUS
    end

    module DateHelper
      extend ActionView::Helpers::DateHelper
    end

    def search_count_reset_in_words(user: nil, session_id: nil)
      seconds = search_count_reset_in(user: user, session_id: session_id)

      if seconds > 1.hour
        I18n.t('datetime.distance_in_words.about_x_hours', count: (seconds / 3600).to_i)
      elsif seconds > 10.minutes
        I18n.t('datetime.distance_in_words.x_minutes', count: (seconds / 60).to_i)
      else
        I18n.t('datetime.distance_in_words.x_seconds', count: seconds.to_i)
      end
    end
  end
end
