module Api
  class Base < ApplicationController
    include SortAndFilterHelper

    layout false

    # before_action -> { head :bad_request }, unless: -> { params[:token] }
    # skip_before_action :verify_authenticity_token

    before_action -> { valid_uid? }
    before_action -> { twitter_user_persisted?(params[:uid].to_i) }
    before_action -> { twitter_db_user_persisted?(params[:uid].to_i) }
    before_action -> { @twitter_user = TwitterUser.latest_by(uid: params[:uid]) }
    before_action -> { authorized_search?(@twitter_user) }

    def summary
      uids, size = summary_uids
      users = TwitterDB::User.where(uid: uids).index_by(&:uid)

      if uids.any? { |uid| !users.has_key?(uid) }
        selected_uids = uids.select { |uid| !users.has_key?(uid) }
        logger.info {"#{controller_name}##{action_name} CreateTwitterDBUserWorker #{selected_uids.size}"}
        CreateTwitterDBUserWorker.perform_async(selected_uids)
      end

      users = uids.map { |uid| users[uid] }.compact.map {|user| Hashie::Mash.new(to_summary_hash(user))}

      chart = [{name: t("charts.#{controller_name}"), y: 100.0 / 3.0}, {name: t('charts.others'),  y: 200.0 / 3.0}]

      render json: {name: controller_name, count: size, users: users, chart: chart}
    end

    def list
      max_sequence = params[:max_sequence].to_i
      limit = (0..10).include?(params[:limit].to_i) ? params[:limit].to_i : 10
      sort_order = USERS_SORT_ORDERS.map {|o| o[1]}.include?(params[:sort_order]) ? params[:sort_order] : USERS_SORT_ORDERS[0][1]
      filter = USERS_FILTERS.map {|f| f[1]}.include?(params[:filter]) ? params[:filter] : nil

      uids, max_sequence =
          if sort_order == USERS_SORT_ORDERS[0][1] && filter.nil?
            list_uids(max_sequence, limit: limit)
          else
            users = list_users.to_a

            case sort_order
              when USERS_SORT_ORDERS[1][1] then users.reverse!
              when USERS_SORT_ORDERS[2][1] then users.sort_by!{|u| -u.friends_count}
              when USERS_SORT_ORDERS[3][1] then users.sort_by!{|u| u.friends_count}
              when USERS_SORT_ORDERS[4][1] then users.sort_by!{|u| -u.followers_count}
              when USERS_SORT_ORDERS[5][1] then users.sort_by!{|u| u.followers_count}
            end

            case filter
              when USERS_FILTERS[0][1] then users.select!(&:inactive?)
            end

            users = users[max_sequence, limit]

            if users.nil? || users.empty?
              [[], -1]
            else
              [users.map(&:uid), max_sequence + (limit - 1)]
            end
          end

      if uids.empty?
        return render json: {name: controller_name, max_sequence: max_sequence, limit: limit, users: []}
      end

      suspended_uids = fetch_suspended_uids? ? fetch_suspended_uids(uids) : []
      blocking_uids = fetch_blocking_uids? ? fetch_blocking_uids : []
      friend_uids = confirm_refollow_uids? ? current_user.twitter_user.friendships.where(friend_uid: uids).pluck(:friend_uid) : []
      follower_uids = confirm_refollowed_uids? ? current_user.twitter_user.followerships.where(follower_uid: uids).pluck(:follower_uid) : []

      users = TwitterDB::User.where(uid: uids).index_by(&:uid)
      users =
        uids.map { |uid| users[uid] }.compact.map do |user|
          suspended = suspended_uids.include?(user.uid)
          blocked = blocking_uids.include?(user.uid)
          refollow = friend_uids.include?(user.uid)
          refollowed = follower_uids.include?(user.uid)
          Hashie::Mash.new(to_list_hash(user, suspended: suspended, blocked: blocked, refollow: refollow, refollowed: refollowed))
        end

      if params[:html]
        users = render_to_string partial: 'twitter/user', collection: users, cached: true, locals: {ad: true}, formats: %i(html)
      end

      render json: {name: controller_name, max_sequence: max_sequence, limit: limit, users: users}
    end

    private

    def log_exception(ex)
      level =
        case ex.message
          when 'No user matches for specified terms.' then :info
          when 'Invalid or expired token.'            then :info
          when 'Your account is suspended and is not permitted to access this feature.' then :info
          else :warn
        end
      logger.send(level, "#{caller[0][/`([^']*)'/, 1] rescue ''}: #{ex.class} #{ex.message} #{current_user_id} #{params.inspect}")
    end

    def fetch_suspended_uids?
      %w(unfriends unfollowers blocking_or_blocked).include?(controller_name)
    end

    def fetch_suspended_uids(uids)
      uids - request_context_client.users(uids).map { |u| u[:id] }
    rescue => e
      log_exception(e)
      []
    end

    def fetch_blocking_uids?
      fetch_suspended_uids? && user_signed_in?
    end

    def fetch_blocking_uids
      request_context_client.blocked_ids
    rescue => e
      log_exception(e)
      []
    end

    def confirm_refollow_uids?
      %w(unfriends blocking_or_blocked).include?(controller_name) && user_signed_in? && current_user.twitter_user
    end

    def confirm_refollowed_uids?
      %w(unfollowers blocking_or_blocked).include?(controller_name) && user_signed_in? && current_user.twitter_user
    end

    def to_summary_hash(user)
      {
        uid: user.uid.to_s,
        screen_name: user.screen_name,
        profile_image_url_https: user.profile_image_url_https.to_s
      }
    end

    def to_list_hash(user, suspended: false, blocked: false, refollow: false, refollowed: false)
      {
        uid: user.uid.to_s,
        screen_name: user.screen_name,
        name: user.name,
        friends_count: user.friends_count,
        followers_count: user.followers_count,
        statuses_count: user.statuses_count,
        profile_image_url_https: user.profile_image_url_https.to_s,
        description: user.description,
        protected: user.protected,
        verified: user.verified,
        suspended: suspended,
        blocked: blocked,
        refollow: refollow,
        refollowed: refollowed,
        inactive: user.inactive
      }
    end
  end
end