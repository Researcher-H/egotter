require 'active_support/concern'

module Concerns::TwitterUser::Persistence
  extend ActiveSupport::Concern

  class_methods do
  end

  included do
    # This method is processed on `after_commit` to avoid long transaction.
    after_commit(on: :create) do

      Util.bm('Total', id, uid) do
        perform_after_commit
      end
      # Set friends_size and followers_size in AssociationBuilder#build_friends_and_followers

    rescue => e
      # ActiveRecord::RecordNotFound Couldn't find TwitterUser with 'id'=00000
      # ActiveRecord::StatementInvalid Mysql2::Error: Deadlock found when trying to get lock;
      logger.warn "#{__method__}: #{e.class} #{e.message.truncate(120)} #{self.inspect}"
      logger.info e.backtrace.join("\n")
      destroy
    end
  end

  def perform_after_commit
    Util.bm('Efs::TwitterUser.import_from!', id, uid) do
      Efs::TwitterUser.import_from!(id, uid, screen_name, raw_attrs_text, @friend_uids, @follower_uids)
    end

    Util.bm('S3::Friendship.import_from!', id, uid) do
      S3::Friendship.import_from!(id, uid, screen_name, @friend_uids, async: true)
    end

    Util.bm('S3::Followership.import_from!', id, uid) do
      S3::Followership.import_from!(id, uid, screen_name, @follower_uids, async: true)
    end

    Util.bm('S3::Profile.import_from!', id, uid) do
      S3::Profile.import_from!(id, uid, screen_name, raw_attrs_text, async: true)
    end

    # S3

    Util.bm('S3::StatusTweet.import_from!', id, uid) do
      tweets = statuses.select(&:new_record?).map { |t| t.slice(:uid, :screen_name, :raw_attrs_text) }
      S3::StatusTweet.import_from!(uid, screen_name, tweets)
    end

    Util.bm('S3::FavoriteTweet.import_from!', id, uid) do
      tweets = favorites.select(&:new_record?).map { |t| t.slice(:uid, :screen_name, :raw_attrs_text) }
      S3::FavoriteTweet.import_from!(uid, screen_name, tweets)
    end

    Util.bm('S3::MentionTweet.import_from!', id, uid) do
      tweets = mentions.select(&:new_record?).map { |t| t.slice(:uid, :screen_name, :raw_attrs_text) }
      S3::MentionTweet.import_from!(uid, screen_name, tweets)
    end

    # EFS

    Util.bm('Efs::StatusTweet.import_from!', id, uid) do
      tweets = statuses.select(&:new_record?).map { |t| t.slice(:uid, :screen_name, :raw_attrs_text) }
      Efs::StatusTweet.import_from!(uid, screen_name, tweets)
    end

    Util.bm('Efs::FavoriteTweet.import_from!', id, uid) do
      tweets = favorites.select(&:new_record?).map { |t| t.slice(:uid, :screen_name, :raw_attrs_text) }
      Efs::FavoriteTweet.import_from!(uid, screen_name, tweets)
    end

    Util.bm('Efs::MentionTweet.import_from!', id, uid) do
      tweets = mentions.select(&:new_record?).map { |t| t.slice(:uid, :screen_name, :raw_attrs_text) }
      Efs::MentionTweet.import_from!(uid, screen_name, tweets)
    end
  end

  module Util
    module_function

    def bm(message, id, uid, &block)
      ApplicationRecord.benchmark("Benchmark Persistence #{id} #{message} #{uid}", level: :info, &block)
    end
  end
end
