class ClustersController < ApplicationController
  include ClustersHelper
  include TweetTextHelper

  before_action :reject_crawler, only: %i(create)
  before_action(only: %i(create show)) { valid_screen_name? && !not_found_screen_name? && !forbidden_screen_name? }
  before_action(only: %i(create show)) { @tu = build_twitter_user_by(screen_name: params[:screen_name]) }
  before_action(only: %i(create show)) { !protected_search?(@tu) }
  before_action(only: %i(show)) { twitter_user_persisted?(@tu.uid.to_i) }
  before_action only: %i(show) do
    @twitter_user = TwitterUser.latest_by(uid: @tu.uid)
    remove_instance_variable(:@tu)
  end

  def new
    @title = t('clusters.new.plain_title')
  end

  def create
    redirect_path = cluster_path(screen_name: @tu.screen_name)
    if TwitterUser.exists?(uid: @tu.uid)
      redirect_to redirect_path
    else
      @screen_name = @tu.screen_name
      @redirect_path = redirect_path
      @via = params['via'].presence || current_via('render_template')
      render template: 'searches/create', formats: %i(html), layout: false
    end
  end

  def show
    stat = UsageStat.find_by(uid: @twitter_user.uid)
    if stat
      clusters = stat.tweet_clusters
      @cluster_names = clusters.keys.take(10).map { |name| t('clusters.show.cluster_name', name: name) }
      @graph = name_y_format(clusters)
    else
      @cluster_names = @graph = []
    end
  end
end
