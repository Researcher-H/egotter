require 'active_support/concern'

module Concerns::JobQueueingConcern
  extend ActiveSupport::Concern

  included do
  end

  def enqueue_create_twitter_user_job_if_needed(uid, user_id:, force: false)
    return if from_crawler?
    return if !force && !user_signed_in?
    return if user_signed_in? && TooManyRequestsUsers.new.exists?(current_user.id)
    return if TwitterUser.latest_by(uid: uid)&.too_short_create_interval?

    request = CreateTwitterUserRequest.create(
        requested_by: controller_name,
        session_id: egotter_visit_id,
        user_id: user_id,
        uid: uid,
        ahoy_visit_id: current_visit&.id)

    debug_info = {
        requested_by: controller_name,
        controller: controller_name,
        action: action_name,
        user_id: user_id,
        uid: uid
    }

    if controller_name == 'searches' && user_signed_in?
      CreateHighPriorityTwitterUserWorker.perform_async(request.id, debug_info: debug_info)
    elsif user_signed_in?
      CreateSignedInTwitterUserWorker.perform_async(request.id, debug_info: debug_info)
    else
      CreateTwitterUserWorker.perform_async(request.id, debug_info: debug_info)
    end

  rescue => e
    logger.warn "#{self.class}##{__method__}: #{e.inspect} uid=#{uid} user_id=#{user_id} requested_by=#{controller_name}"
  end

  def enqueue_assemble_twitter_user(twitter_user)
    return if from_crawler?
    return unless user_signed_in?

    if twitter_user.assembled_at.blank?
      request = AssembleTwitterUserRequest.create(twitter_user: twitter_user)
      AssembleTwitterUserWorker.perform_async(request.id, requested_by: controller_name)
    end
  end

  def enqueue_update_authorized
    return if from_crawler?
    return unless user_signed_in?
    UpdateAuthorizedWorker.perform_async(current_user.id)
  end

  def enqueue_update_egotter_friendship
    return if from_crawler?
    return unless user_signed_in?
    UpdateEgotterFriendshipWorker.perform_async(current_user.id)
  end

  def enqueue_audience_insight(uid)
    return if from_crawler?
    UpdateAudienceInsightWorker.perform_async(uid, location: controller_name)
  end
end
