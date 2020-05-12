require 'rails_helper'

RSpec.describe CreatePeriodicReportMessageWorker do
  let(:user) { create(:user) }
  let(:worker) { described_class.new }

  describe '#unique_key' do
    it { expect(worker.unique_key(user.id)).to eq(user.id) }

    context 'user_id is nil' do
      it { expect(worker.unique_key(nil, {uid: user.uid})).to eq("uid-#{user.uid}") }
      it { expect(worker.unique_key(nil, {'uid' => user.uid})).to eq("uid-#{user.uid}") }
    end
  end

  describe '#perform' do
    subject { worker.perform(user_id, options) }

    before do
      user.create_notification_setting!
      allow(user.notification_setting).to receive(:enough_permission_level?).and_return(true)
      allow(User).to receive(:find).with(user.id).and_return(user)
    end

    context 'options[:unregistered] is specified' do
      let(:user_id) { nil }
      let(:options) { {unregistered: true, uid: 1} }
      it do
        expect(worker).to receive(:perform_unregistered).with(1)
        subject
      end
    end

    context 'options[:restart_requested] is specified' do
      let(:user_id) { user.id }
      let(:options) { {restart_requested: true} }
      it do
        expect(worker).to receive(:perform_restart_request).with(user)
        subject
      end
    end

    context 'options[:stop_requested] is specified' do
      let(:user_id) { user.id }
      let(:options) { {stop_requested: true} }
      it do
        expect(worker).to receive(:perform_stop_request).with(user)
        subject
      end
    end

    context 'options[:permission_level_not_enough] is specified' do
      let(:user_id) { user.id }
      let(:options) { {permission_level_not_enough: true} }
      it do
        expect(worker).to receive(:perform_permission_level_not_enough).with(user)
        subject
      end
    end

    context 'options[:unauthorized] is specified' do
      let(:user_id) { user.id }
      let(:options) { {unauthorized: true} }
      it do
        expect(worker).to receive(:perform_unauthorized).with(user)
        subject
      end
    end

    context 'options[:interval_too_short] is specified' do
      let(:user_id) { user.id }
      let(:options) { {interval_too_short: true} }
      it do
        expect(PeriodicReport).to receive_message_chain(:interval_too_short_message, :deliver!).with(user.id).with(no_args)
        subject
      end
    end

    context 'an exception is raised' do
      let(:user_id) { user.id }
      let(:options) { {} }
      before { allow(options).to receive(:symbolize_keys!).and_raise('anything') }

      context "not_fatal_error? returns true" do
        before { allow(worker).to receive(:not_fatal_error?).with(anything).and_return(true) }
        it do
          expect(worker.logger).to receive(:info).with(instance_of(String))
          subject
        end
      end

      context "unknown exception is raised" do
        it do
          expect(worker.logger).to receive(:warn).with(instance_of(String))
          subject
        end
      end
    end
  end

  describe '#perform_unregistered' do
    let(:message) { PeriodicReport.unregistered_message.message }
    subject { worker.perform_unregistered(('uid')) }
    it do
      expect(worker).to receive(:send_message_from_egotter).with('uid', message)
      subject
    end
  end

  describe '#perform_restart_request' do
    let(:message) { PeriodicReport.restart_requested_message.message }
    subject { worker.perform_restart_request(user) }
    it do
      expect(worker).to receive(:send_message_from_egotter).with(user.uid, message)
      subject
    end
  end

  describe '#perform_stop_request' do
    let(:message) { PeriodicReport.stop_requested_message.message }
    subject { worker.perform_stop_request(user) }
    it do
      expect(worker).to receive(:send_message_from_egotter).with(user.uid, message, unsubscribe: true)
      subject
    end
  end

  describe '#perform_permission_level_not_enough' do
    let(:message) { PeriodicReport.permission_level_not_enough_message.message }
    subject { worker.perform_permission_level_not_enough(user) }
    it do
      expect(worker).to receive(:send_message_from_egotter).with(user.uid, message)
      subject
    end
  end

  describe '#perform_unauthorized' do
    let(:message) { PeriodicReport.unauthorized_message.message }
    subject { worker.perform_unauthorized(user) }
    it do
      expect(worker).to receive(:send_message_from_egotter).with(user.uid, message)
      subject
    end
  end

  describe '#send_message_from_egotter' do
    subject { worker.send_message_from_egotter('uid', 'message', 'options') }
    it do
      expect(PeriodicReport).to receive(:build_direct_message_event).
          with('uid', 'message', 'options').and_return('event')
      expect(User).to receive_message_chain(:egotter, :api_client, :create_direct_message_event).with(event: 'event')
      subject
    end
  end

  describe '#not_fatal_error?' do
    let(:error) { RuntimeError.new('error') }
    subject { worker.not_fatal_error?(error) }

    %i(
      you_have_blocked?
      not_following_you?
      cannot_find_specified_user?
      protect_out_users_from_spam?
      your_account_suspended?
      cannot_send_messages?
    ).each do |method|
      context "#{method} returns true" do
        before { allow(DirectMessageStatus).to receive(method).with(error).and_return(true) }
        it { is_expected.to be_truthy }
      end
    end

    context "unknown exception is raised" do
      it { is_expected.to be_falsey }
    end
  end
end