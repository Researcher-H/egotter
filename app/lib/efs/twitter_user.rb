# -*- SkipSchemaAnnotations

require 'active_support'
require 'active_support/cache/file_store'

module Efs
  class TwitterUser
    extend ::Efs::Util

    attr_reader :uid, :screen_name, :profile, :friend_uids, :follower_uids

    def initialize(attrs)
      @uid = attrs[:uid]
      @screen_name = attrs[:screen_name]
      @profile = attrs[:profile]
      @friend_uids = attrs[:friend_uids]
      @follower_uids = attrs[:follower_uids]
    end

    class << self
      def find_by(twitter_user_id)
        obj = cache_client.read(cache_key(twitter_user_id))
        obj ? new(parse_json(decompress(obj))) : nil
      rescue => e
        Rails.logger.info { "#{self}##{__method__} failed #{e.inspect} twitter_user_id=#{twitter_user_id}" }
        nil
      end

      def delete_by(twitter_user_id)
        cache_client.delete(cache_key(twitter_user_id))
      end

      def import_from!(twitter_user_id, uid, screen_name, profile, friend_uids, follower_uids)
        profile = parse_json(profile) if profile.class == String
        payload = {
            twitter_user_id: twitter_user_id,
            uid: uid,
            screen_name: screen_name,
            profile: profile,
            friend_uids: friend_uids,
            follower_uids: follower_uids
        }.to_json
        cache_client.write(cache_key(twitter_user_id), compress(payload))
      end

      def cache_key(twitter_user_id)
        "efs_twitter_user_cache:#{twitter_user_id}"
      end

      # TODO Use Efs::Client

      def cache_client
        @m ||= Mutex.new
        @m.synchronize do
          if instance_variable_defined?(:@cache_client)
            @cache_client
          else
            dir = Rails.root.join(CacheDirectory.find_by(name: 'efs_twitter_user')&.dir || 'tmp/efs_cache')
            FileUtils.mkdir_p(dir) unless File.exists?(dir)
            options = {expires_in: 1.month, race_condition_ttl: 5.minutes}
            @cache_client = ActiveSupport::Cache::FileStore.new(dir, options)
          end
        end
      end
    end
  end
end
