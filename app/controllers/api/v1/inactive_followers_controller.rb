module Api
  module V1
    class InactiveFollowersController < ::Api::V1::Base

      private

      def summary_uids(limit: SUMMARY_LIMIT)
        uids = @twitter_user.inactive_followerships.limit(limit).pluck(:follower_uid)
        size = @twitter_user.inactive_followerships.size
        [uids, size]
      end

      def list_users
        limit = user_signed_in? && current_user.has_valid_subscription? ? Order::BASIC_PLAN_USERS_LIMIT : Order::FREE_PLAN_USERS_LIMIT
        @twitter_user.inactive_followers(limit: limit)
      end
    end
  end
end