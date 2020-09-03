# == Schema Information
#
# Table name: close_friends_og_images
#
#  id         :bigint(8)        not null, primary key
#  uid        :bigint(8)        not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_close_friends_og_images_on_uid  (uid) UNIQUE
#
require 'yaml'
require 'tempfile'

class CloseFriendsOgImage < ApplicationRecord
  has_one_attached :image

  validates :uid, presence: true, uniqueness: true

  def cdn_url
    image.attached? ? "https://#{ENV['OG_IMAGE_ASSET_HOST']}/#{image.blob.key}" : nil
  end

  def update_acl(value = 'public-read')
    config = YAML.load(ERB.new(File.read('config/storage.yml')).result)['amazon']
    client = Aws::S3::Client.new(region: config['region'], retry_limit: 4, http_open_timeout: 3, http_read_timeout: 3)
    client.put_object_acl(acl: value, bucket: config['bucket'], key: image.blob.key)
  end

  class Generator

    OG_IMAGE_IMAGEMAGICK = ENV['OG_IMAGE_IMAGEMAGICK']
    OG_IMAGE_OUTLINE = 'public/og_image/egotter_og_outline_840x450.png'
    OG_IMAGE_HEART = 'public/og_image/heart_300x350.svg'
    OG_IMAGE_FONT = 'public/og_image/azukiP.ttf'

    class << self
      def generate(twitter_user, friends, &block)
        text = I18n.t('og_image_text.close_friends', user: twitter_user.screen_name, friend1: friends[0][:screen_name], friend2: friends[1][:screen_name], friend3: friends[2][:screen_name])
        outfile = "public/og_image/close_friends_og_image_#{twitter_user.uid}.png"
        heart = generate_heart_image(friends)

        begin
          generate_image(text, heart, outfile)
          yield(outfile)
        ensure
          File.delete(outfile) if File.exist?(outfile)
        end
      end

      def generate_heart_image(users)
        heart = File.read(OG_IMAGE_HEART)

        100.times do |i|
          user = users[i]

          if i < 3
            if user
              heart.sub!("screen_name_#{i}", user[:screen_name])
            else
              heart.sub!("screen_name_#{i}", '')
            end
          end

          if user
            heart.sub!("image_url_#{i}", user[:profile_image_url_https])
          else
            heart.sub!(/<image.+image_url_#{i}.+<\/image>/, '')
          end
        end

        heart
      end

      def generate_image(text, heart, outfile)
        system(%Q(#{OG_IMAGE_IMAGEMAGICK} #{OG_IMAGE_OUTLINE} -font "#{OG_IMAGE_FONT}" -fill black -pointsize 24 -interline-spacing 20 -annotate +50+120 "#{text}" #{outfile}))
        Tempfile.open(['heart', '.svg']) do |f|
          f.write heart
          system(%Q(#{OG_IMAGE_IMAGEMAGICK} #{outfile} #{f.path} -gravity center -geometry +200+0 -composite #{outfile}))
        end
      end
    end
  end
end
