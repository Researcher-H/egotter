require 'rails_helper'

RSpec.describe TweetRequest, type: :model do
  let(:user) { create(:user) }

  describe '.share_suffix' do
    subject { described_class.share_suffix }
    it { is_expected.to be_truthy }
  end

  describe '.create_status!' do
    let(:client) { double('client') }
    let(:text) { 'text' }
    subject { described_class.send(:create_status!, client, text) }

    it do
      expect(client).to receive(:update).with(text)
      subject
    end
  end
end

RSpec.describe TweetRequest::TextValidator, type: :model do

  describe '#valid?' do
    subject { described_class.new(text).valid? }

    [
        'Hello. https://egotter.com',
        "@user Hello. \n https://egotter.com",
        "https://egotter.com\nGreat!",
        'hello https://egotter.com/' + 'a' * 200,
    ].each do |str|
      context "text is #{str}" do
        let(:text) { str }
        it { is_expected.to be_truthy }
      end
    end

    [
        'えごったーおもろいꉂꉂ(ᵔᗜᵔ*)',
    ].each do |str|
      context "text is #{str}" do
        let(:text) { str }
        it { is_expected.to be_falsey }
      end
    end
  end
end
