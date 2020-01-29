require 'twitter'

# It is necessary to load the classes first because they may be called in Thread.
require_relative '../../app/models/call_create_friendship_count'
require_relative '../../app/models/call_user_timeline_count'

module Egotter
  module Twitter
    module Measurement
      def follow!(*args)
        super
      ensure
        CallCreateFriendshipCount.new.increment
      end

      def user_timeline(*args)
        super
      ensure
        CallUserTimelineCount.new.increment
      end
    end
  end
end

::Twitter::REST::Client.prepend(::Egotter::Twitter::Measurement)