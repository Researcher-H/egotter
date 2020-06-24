class ForbiddenController < ApplicationController
  include Concerns::CheckExistenceConcern

  prepend_before_action do
    @resource_name = 'forbidden'
  end

  private

  def resource_found?
    !ForbiddenUser.exists?(screen_name: params[:screen_name]) &&
        !forbidden_user?(params[:screen_name]) &&
        params['redirect'] != 'false'
  end

  def latest_resource_path(screen_name)
    @latest_resource_path = latest_forbidden_path(screen_name: screen_name, via: current_via('request_to_update'))
  end

  def set_canonical_url
    @canonical_url =
        if @user
          forbidden_url(@user)
        else
          forbidden_url(screen_name: @screen_name)
        end
  end
end
