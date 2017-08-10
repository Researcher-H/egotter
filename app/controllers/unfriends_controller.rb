class UnfriendsController < ApplicationController
  include Validation
  include Concerns::Logging
  include SearchesHelper
  include TweetTextHelper
  include WorkersHelper

  before_action(only: %i(show)) do
    if request.format.html?
      if valid_screen_name?(params[:screen_name])
        case params[:type]
          when 'removing' then redirect_to(unfriend_path(screen_name: params[:screen_name]), status: 301)
          when 'removed' then redirect_to(unfollower_path(screen_name: params[:screen_name]), status: 301)
          when 'blocking_or_blocked' then redirect_to(blocking_or_blocked_path(screen_name: params[:screen_name]), status: 301)
        end
      end
    else
      head :not_found
    end
  end

  before_action(only: %i(show)) { valid_screen_name?(params[:screen_name]) }
  before_action(only: %i(show)) { not_found_screen_name?(params[:screen_name]) }
  before_action(only: %i(show)) { @tu = build_twitter_user(params[:screen_name]) }
  before_action(only: %i(show)) { authorized_search?(@tu) }
  before_action(only: %i(show)) { existing_uid?(@tu.uid.to_i) }
  before_action(only: %i(show)) do
    @twitter_user = TwitterUser.latest(@tu.uid.to_i)
    remove_instance_variable(:@tu)
  end
  before_action only: %i(new create show) do
    if request.format.html?
      push_referer
      create_search_log
    end
  end

  def new
  end

  def show
    @api_path = send("api_v1_#{controller_name}_list_path")
    @breadcrumb_name = controller_name.singularize.to_sym
    @canonical_url = send("#{controller_name.singularize}_url", screen_name: @twitter_user.screen_name)
    @page_title = t('.page_title', user: @twitter_user.mention_name)

    counts = {
      unfriends: @twitter_user.unfriendships.size,
      unfollowers: @twitter_user.unfollowerships.size,
      blocking_or_blocked: @twitter_user.blocking_or_blocked_uids.size
    }

    @meta_title = t('.meta_title', {user: @twitter_user.mention_name}.merge(counts))

    @page_description = t('.page_description', user: @twitter_user.mention_name)
    @meta_description = t('.meta_description', {user: @twitter_user.mention_name}.merge(counts))

    mention_names = @twitter_user.unfriends.select(:screen_name).limit(3).map(&:mention_name)
    names = '.' + honorific_names(mention_names)
    @tweet_text = t('.tweet_text', users: names, url: @canonical_url)

    @stat = UsageStat.find_by(uid: @twitter_user.uid)

    @jid = add_create_twitter_user_worker_if_needed(@twitter_user.uid, user_id: current_user_id, screen_name: @twitter_user.screen_name)
  end
end
