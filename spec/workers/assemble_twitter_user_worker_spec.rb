require 'rails_helper'

RSpec.describe AssembleTwitterUserWorker do
  let(:twitter_user) {create(:twitter_user, with_relations: false)}
  let(:request) { create(:assemble_twitter_user_request, twitter_user: twitter_user) }
  let(:worker) { described_class.new }

  describe '#unique_key' do
    subject { worker.unique_key(request.id, {}) }
    it do
      is_expected.to eq(twitter_user.uid)
    end
  end

  describe '#after_timeout' do
    subject { worker.after_timeout(request.id) }
    it do
      expect(TimedOutAssembleTwitterUserWorker).to receive(:perform_async).with(request.id, {})
      subject
    end
  end
end
