require 'rails_helper'

RSpec.describe JobQueueingConcern do
  let(:instance) { double('Instance') }

  before do
    instance.extend JobQueueingConcern
  end

  describe '#enqueue_create_twitter_user_job_if_needed' do
    let(:user) { create(:user) }
    subject { instance.enqueue_create_twitter_user_job_if_needed(user.uid, user_id: user.id) }
    before do
      allow(instance).to receive(:from_crawler?).and_return(false)
      allow(instance).to receive(:user_signed_in?).and_return(true)
      allow(instance).to receive(:current_user).and_return(user)
      allow(instance).to receive(:controller_name).and_return('controller')
      allow(instance).to receive(:action_name).and_return('action')
      allow(instance).to receive(:egotter_visit_id).and_return('visit_id')
      allow(instance).to receive(:current_visit).and_return(nil)
    end
    it do
      expect(CreateSignedInTwitterUserWorker).to receive(:perform_async).with(any_args).and_return('jid')
      is_expected.to eq('jid')
    end
  end
end
