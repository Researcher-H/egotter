require 'active_support/concern'

module FollowRequestRunnable
  extend ActiveSupport::Concern

  class_methods do
  end

  def finished!
    update!(finished_at: Time.zone.now) if finished_at.nil?
  end

  def finished?
    !finished_at.nil?
  end
end
