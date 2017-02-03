class SearchesController < ApplicationController
  include Validation
  include Concerns::Logging
  include SearchesHelper
  include PageCachesHelper

  before_action :need_login,     only: %i(common_friends common_followers)
  before_action :reject_crawler, only: %i(create waiting)
  before_action(only: Search::MENU + %i(create show)) { valid_screen_name?(params[:screen_name]) }
  before_action(only: Search::MENU + %i(create show)) { not_found_screen_name?(params[:screen_name]) }
  before_action(only: Search::MENU + %i(create show)) { @tu = build_twitter_user(params[:screen_name]) }
  before_action(only: Search::MENU + %i(create show)) { authorized_search?(@tu) }
  before_action(only: Search::MENU + %i(show)) { existing_uid?(@tu.uid.to_i) }
  before_action only: Search::MENU + %i(show) do
    @searched_tw_user = TwitterUser.latest(@tu.uid.to_i)
    remove_instance_variable(:@tu)
  end
  before_action(only: %i(waiting)) { valid_uid?(params[:uid].to_i) }
  before_action(only: %i(waiting)) { searched_uid?(params[:uid].to_i) }

  before_action only: (%i(new create waiting show) + Search::MENU) do
    push_referer

    if session[:sign_in_from].present?
      create_search_log(referer: session.delete(:sign_in_from))
    elsif session[:sign_out_from].present?
      create_search_log(referer: session.delete(:sign_out_from))
    else
      create_search_log
    end
  end

  def show
    tu = @searched_tw_user
    page_cache = ::Cache::PageCache.new
    if via_notification?
      if via_prompt_report?
        # A worker is started because the record is not updated in the process of creating a prompt report.
        if tu.forbidden_account?
          flash.now[:alert] = forbidden_message(tu.screen_name)
          @worker_started = false
        else
          @worker_started = !!add_create_twitter_user_worker_if_needed(tu.uid, user_id: current_user_id, screen_name: tu.screen_name)
        end
      else
        # When a guest or user accesses this action via a notification which includes search and update,
        # no worker is started. Because the record is updated in the process of creating a notification.
        # page_cache.delete(tu.uid)
      end
    else
      # Under the following circumstances, a worker is started.
      # 1. When a guest or user accesses this action directly
      # 2. When a guest or user accesses `create` action and searched TwitterUser exists
      if tu.forbidden_account?
        flash.now[:alert] = forbidden_message(tu.screen_name)
        @worker_started = false
      else
        @worker_started = !!add_create_twitter_user_worker_if_needed(tu.uid, user_id: current_user_id, screen_name: tu.screen_name)
      end
      @page_cache = page_cache.read(tu.uid) if page_cache.exists?(tu.uid)
    end
  end

  def new
  end

  def create
    uid, screen_name = @tu.uid.to_i, @tu.screen_name
    redirect_path = sanitized_redirect_path(params[:redirect_path].presence || search_path(screen_name: screen_name))
    if TwitterUser.exists?(uid: uid)
      redirect_to redirect_path
    else
      save_twitter_user_to_cache(uid, screen_name: screen_name, user_info: @tu.user_info)
      add_create_twitter_user_worker_if_needed(uid, user_id: current_user_id, screen_name: screen_name)
      redirect_to waiting_search_path(uid: uid, redirect_path: redirect_path)
    end
  end

  def waiting
    uid = params[:uid].to_i
    tu = fetch_twitter_user_from_cache(uid)
    if tu.nil?
      return redirect_to root_path, alert: t('before_sign_in.that_page_doesnt_exist')
    end
    @redirect_path = sanitized_redirect_path(params[:redirect_path].presence || search_path(screen_name: tu.screen_name))
    @searched_tw_user = tu
  end

  Search::MENU.select { |menu| %i(one_sided_friends one_sided_followers mutual_friends removing removed blocking_or_blocked).exclude?(menu) }.each do |menu|
    define_method(menu) do
      @menu = menu
      @title = title_for(@searched_tw_user, menu: menu)
      render :common
    end
  end

  %i(one_sided_friends one_sided_followers mutual_friends).each do |menu|
    define_method(menu) do
      redirect_to one_sided_friend_path(screen_name: @searched_tw_user.screen_name, type: menu)
    end
  end

  %i(removing removed blocking_or_blocked).each do |menu|
    define_method(menu) do
      redirect_to unfriend_path(screen_name: @searched_tw_user.screen_name, type: menu)
    end
  end

  def debug
    unless request.device_type == :crawler
      logger.warn "#{self.class}##{__method__}: #{current_user_id} #{request.device_type} #{request.method} #{request.url}"
    end
    redirect_to root_path
  end
end
