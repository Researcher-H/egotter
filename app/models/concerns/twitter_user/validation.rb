require 'active_support/concern'

module Concerns::TwitterUser::Validation
  extend ActiveSupport::Concern

  TOO_MANY_FRIENDS = 5000

  included do
    validates :uid, presence: true, numericality: :only_integer
    validates :screen_name, presence: true, length: {maximum: 30}
    validates :user_info, presence: true

    validate :unauthorized?
    validate :suspended_account?
    validate :inconsistent_friends?
    validate :zero_friends?
    validate :too_many_friends?
    validate :recently_created_record_exists?
    validate :same_record_exists?

    def unauthorized?
      if protected && !User.exists?(uid: uid.to_i)
        errors[:base] << 'unauthorized'
        return true
      end

      false
    end

    def suspended_account?
      if suspended
        errors[:base] << 'suspended'
        return true
      end

      false
    end

    def inconsistent_friends?
      if friends_count != friends.size || followers_count != followers.size
        errors[:base] << 'friends or followers is inconsistent'
        return true
      end

      false
    end

    def zero_friends?
      if friends_count + followers_count <= 0
        errors[:base] << 'sum of friends and followers is zero'
        return true
      end

      false
    end

    def too_many_friends?
      if friends_count + followers_count > TOO_MANY_FRIENDS
        errors[:base] << 'too many friends and followers'
        return true
      end

      false
    end

    def recently_created_record_exists?
      me = latest_me
      return false if me.blank?

      if me.recently_created? || me.recently_updated?
        errors[:base] << 'recently created record exists'
        return true
      end

      false
    end

    def same_record_exists?
      same_record?(latest_me)
    end

    def same_record?(tu)
      return false if tu.blank?
      raise "uid is different(#{self.uid},#{tu.uid})" if self.uid.to_i != tu.uid.to_i

      if tu.friends_count != self.friends_count || tu.followers_count != self.followers_count
        logger.debug "#{screen_name} friends_count or followers_count is different"
        return false
      end

      if tu.friend_uids != self.friend_uids || tu.follower_uids != self.follower_uids
        logger.debug "#{screen_name} friend_uids or follower_uids is different"
        return false
      end

      errors[:base] << "id:#{tu.id} is the same record"
      true
    end
  end
end