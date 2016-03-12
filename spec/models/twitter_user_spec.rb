require 'rails_helper'

RSpec.describe TwitterUser, type: :model do
  let(:tu) { build(:twitter_user) }

  let(:client) {
    client = Object.new
    def client.user?(*args)
      true
    end
    def client.user(*args)
      Hashie::Mash.new({id: 1, screen_name: 'sn'})
    end
    client
  }

  describe '#invalid_screen_name?' do
    context 'screen_name has special chars' do
      it 'returns true' do
        (%w(! " # $ % & ' - = ^ ~ ¥ \\ | @ ; + : * [ ] { } < > / ?) + %w[( )]).each do |c|
          tu.screen_name = c * 10
          expect(tu.invalid_screen_name?).to be_truthy
        end
      end
    end

    context 'screen_name has normal chars' do
      it 'returns false' do
        tu.screen_name = 'ego_tter'
        expect(tu.invalid_screen_name?).to be_falsy
      end
    end
  end

  describe '#same_record_exists?' do
    before do
      raise 'save_with_bulk_insert failed' unless tu.save_with_bulk_insert
      friends = tu.friends.map { |f| build(:friend, uid: f.uid, screen_name: f.screen_name) }
      followers = tu.followers.map { |f| build(:follower, uid: f.uid, screen_name: f.screen_name) }
      @new_tu = build(:twitter_user, uid: tu.uid, screen_name: tu.screen_name, friends: friends, followers: followers)
    end

    context 'same record is persisted' do
      it 'returns true' do
        expect(@new_tu.same_record_exists?).to be_truthy
      end
    end

    context 'same record is not persisted' do
      before do
        tu.destroy
      end

      it 'returns true' do
        expect(@new_tu.same_record_exists?).to be_falsey
      end
    end

    context 'friends_count is different' do
      before do
        json = Hashie::Mash.new(JSON.parse(@new_tu.user_info))
        json.friends_count += 1
        @new_tu.user_info = json.to_json
      end

      it 'returns false' do
        expect(@new_tu.same_record_exists?).to be_falsey
      end
    end

    context 'followers_count is different' do
      before do
        json = Hashie::Mash.new(JSON.parse(@new_tu.user_info))
        json.followers_count += 1
        @new_tu.user_info = json.to_json
      end

      it 'returns false' do
        expect(@new_tu.same_record_exists?).to be_falsey
      end
    end
  end
end
