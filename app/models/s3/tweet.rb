# -*- SkipSchemaAnnotations

module S3
  class Tweet
    attr_reader :raw_attrs_text

    def initialize(tweet)
      @raw_attrs_text = tweet['raw_attrs_text']
    end

    class << self
      def bucket_name
        'not-specified'
      end

      def array_from(tweets)
        tweets.map { |t| new(t) }
      end

      def where(uid:)
        obj = client.read(uid)
        obj ? array_from(decode(obj)['tweets']) : []
      rescue Aws::S3::Errors::NoSuchKey => e
        []
      end

      def import_from!(uid, screen_name, tweets)
        body = encode(uid, screen_name, tweets)
        client.write(uid, body)
      end

      def delete(uid:)
        client.delete(uid)
      end

      def encode(uid, screen_name, tweets)
        {
            uid: uid,
            screen_name: screen_name,
            tweets: ::S3::Util.pack(tweets),
            time: Time.zone.now.to_s,
        }.to_json
      end

      def decode(obj)
        obj = ::S3::Util.parse_json(obj)
        obj['tweets'] = ::S3::Util.unpack(obj['tweets'])
        obj
      end

      def client
        @client ||= ::S3::Client.new(bucket_name, self)
      end
    end
  end
end
