class  Page::GoodFriends < ::Page::Base
  include TweetTextHelper

  def all
    initialize_instance_variables
    @collection = @twitter_user.users_by(controller_name: controller_name)
  end

  def show
    initialize_instance_variables
  end

  private

  def initialize_instance_variables
    @api_path = send("api_v1_#{controller_name}_list_path")
    @breadcrumb_name, @canonical_url =
      if action_name == 'show'
        [controller_name.singularize.to_sym, send("#{controller_name.singularize}_url", @twitter_user)]
      else
        ["all_#{controller_name}".to_sym, send("all_#{controller_name}_url", @twitter_user)]
      end

    users = @twitter_user.users_by(controller_name: controller_name).limit(5)

    @tweet_text = good_friends_text(users, @twitter_user)
  end

  def good_friends_text(users, twitter_user)
    via = "close_friends#{l(Time.zone.now.in_time_zone('Tokyo'), format: :share_text_short)}"
    share_url =
        if action_name == 'show'
          send("#{controller_name.singularize}_url", @twitter_user, via: via)
        else
          send("all_#{controller_name}_url", @twitter_user, via: via)
        end

    mention_names = users.map.with_index { |u, i| "#{i + 1}. #{u.mention_name}" }
    t('.tweet_text', user: twitter_user.mention_name, users: mention_names.join("\n"), url: share_url)
  end
end
