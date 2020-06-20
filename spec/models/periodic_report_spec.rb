require 'rails_helper'

RSpec.describe PeriodicReport do
  let(:user) { create(:user, with_credential_token: true) }
  let(:request) { double('request', id: 1) }
  let(:start_date) { 1.day.ago }
  let(:end_date) { Time.zone.now }
  let(:unfriends) { %w(a b c) }
  let(:total_unfollowers) { %w(x1 y1 z1) }

  describe '.periodic_message' do
    subject do
      described_class.periodic_message(
          user.id,
          request_id: request.id,
          start_date: start_date,
          end_date: end_date,
          unfriends: unfriends,
          unfollowers: unfollowers,
          total_unfollowers: total_unfollowers
      )
    end

    context 'unfollowers.size is greater than 1' do
      let(:unfollowers) { %w(x y z) }
      it { is_expected.to be_truthy }
    end

    context 'unfollowers.size is 1' do
      let(:unfollowers) { [] }
      it { is_expected.to be_truthy }
    end
  end

  describe '.periodic_push_message' do
    subject do
      described_class.periodic_push_message(
          user.id,
          request_id: request.id,
          start_date: start_date,
          end_date: end_date,
          unfriends: unfriends,
          unfollowers: unfollowers
      )
    end

    context 'unfollowers.size is greater than 1' do
      let(:unfollowers) { %w(x y z) }
      it { is_expected.to be_truthy }
    end

    context 'unfollowers.size is 1' do
      let(:unfollowers) { [] }
      it { is_expected.to be_truthy }
    end
  end

  describe '.request_id_text' do
    subject { described_class.request_id_text(user, 1, 'CreateUserRequestedPeriodicReportWorker') }
    before { user.create_periodic_report_setting! }
    it { is_expected.to be_truthy }
  end

  describe '#send_direct_message' do
    let(:report) { described_class.new(message: 'message') }
    let(:recipient) { double('recipient', uid: 2) }
    subject { report.send_direct_message }

    before { allow(report).to receive(:report_recipient).and_return(recipient) }

    it do
      expect(described_class).to receive(:build_direct_message_event).with(recipient.uid, 'message').and_return('event')
      expect(report).to receive_message_chain(:report_sender, :api_client, :create_direct_message_event).with(event: 'event').and_return('dm')
      expect(report).to receive(:send_remind_message_if_needed)
      is_expected.to eq('dm')
    end
  end

  describe '#send_remind_message_if_needed' do
    let(:report) { described_class.new }
    subject { report.send_remind_message_if_needed }

    context 'send_remind_reply_message? returns true' do
      before { allow(report).to receive(:send_remind_reply_message?).and_return(true) }
      it do
        expect(report).to receive(:send_remind_reply_message)
        subject
      end
    end

    context 'send_remind_access_message? returns true' do
      before do
        allow(report).to receive(:send_remind_reply_message?).and_return(false)
        allow(report).to receive(:send_remind_access_message?).and_return(true)
      end
      it do
        expect(report).to receive(:send_remind_access_message)
        subject
      end
    end
  end

  describe '#send_remind_reply_message?' do
    let(:report) { described_class.new }
    subject { report.send_remind_reply_message? }

    before { allow(report).to receive(:user).and_return(user) }

    context 'dont_send_remind_message is set' do
      before { report.dont_send_remind_message = true }
      it { is_expected.to be_falsey }
    end

    context 'messages_allotted? returns true' do
      before { allow(described_class).to receive(:messages_allotted?).with(user).and_return(true) }
      it do
        expect(described_class).to receive(:allotted_messages_will_expire_soon?).with(user).and_return('result')
        is_expected.to eq('result')
      end
    end

    context 'messages_allotted? returns false' do
      before { allow(described_class).to receive(:messages_allotted?).with(user).and_return(false) }
      it { is_expected.to be_truthy }
    end
  end

  describe '#send_remind_access_message?' do
    let(:report) { described_class.new }
    subject { report.send_remind_access_message? }

    before { allow(report).to receive(:user).and_return(user) }

    context 'dont_send_remind_message is set' do
      before { report.dont_send_remind_message = true }
      it { is_expected.to be_falsey }
    end

    context 'messages_allotted? returns true' do
      before { allow(described_class).to receive(:messages_allotted?).with(user).and_return(true) }
      it do
        expect(described_class).to receive(:no_access_days_user?).with(user).and_return('result')
        is_expected.to eq('result')
      end
    end

    context 'messages_allotted? returns false' do
      before { allow(described_class).to receive(:messages_allotted?).with(user).and_return(false) }
      it { is_expected.to be_truthy }
    end
  end

  describe '#send_remind_reply_message' do
    let(:report) { described_class.new }
    subject { report.send_remind_reply_message }

    before { allow(report).to receive(:user).and_return(user) }

    it do
      expect(described_class).to receive(:remind_reply_message).and_call_original
      expect(report).to receive(:send_remind_message).with(instance_of(String))
      subject
    end
  end

  describe '#send_remind_access_message' do
    let(:report) { described_class.new }
    subject { report.send_remind_access_message }

    before { allow(report).to receive(:user).and_return(user) }

    it do
      expect(described_class).to receive(:remind_access_message).and_call_original
      expect(report).to receive(:send_remind_message).with(instance_of(String))
      subject
    end
  end

  describe '#send_remind_message' do
    let(:report) { described_class.new }
    subject { report.send_remind_message('message') }

    before { allow(report).to receive(:user).and_return(user) }

    it do
      expect(described_class).to receive(:build_direct_message_event).with(user.uid, 'message').and_return('event')
      expect(User).to receive_message_chain(:egotter, :api_client, :create_direct_message_event).with(no_args).with(event: 'event')
      subject
    end
  end

  describe '.allotted_messages_will_expire_soon?' do
    subject { described_class.allotted_messages_will_expire_soon?(user) }

    before do
      allow(GlobalDirectMessageReceivedFlag).to receive_message_chain(:new, :remaining).with(user.uid).and_return(ttl)
    end

    context 'remaining ttl is short' do
      let(:ttl) { 1.hour }
      it { is_expected.to be_truthy }
    end

    context 'remaining ttl is long' do
      let(:ttl) { 6.hours }
      it { is_expected.to be_falsey }
    end
  end

  describe '.no_access_days_user?' do
    subject { described_class.no_access_days_user?(user) }

    context "user doesn't have access_days" do
      it { is_expected.to be_nil }
    end

    context "user has recent access_days" do
      let(:user) { create(:user, with_access_days: 1) }
      it { is_expected.to be_falsey }
    end

    context "user has access_days but the value is a long time ago" do
      let(:user) { create(:user, with_access_days: 1) }
      before { user.access_days.last.update!(date: 1.month.ago.to_date) }
      it { is_expected.to be_truthy }
    end
  end

  describe '.allotted_messages_left?' do
    subject { described_class.allotted_messages_left?(user) }

    context 'Sending DMs count is less than or equal to 4' do
      before { allow(GlobalSendDirectMessageCountByUser).to receive_message_chain(:new, :count).with(user.uid).and_return(4) }
      it { is_expected.to be_truthy }
    end

    context 'Sending DMs count is greater than 3' do
      before { allow(GlobalSendDirectMessageCountByUser).to receive_message_chain(:new, :count).with(user.uid).and_return(5) }
      it { is_expected.to be_falsey }
    end
  end

  describe '.messages_allotted?' do
    subject { described_class.messages_allotted?(user) }

    it do
      expect(GlobalDirectMessageReceivedFlag).to receive_message_chain(:new, :received?).with(user.uid).and_return('result')
      is_expected.to eq('result')
    end
  end

  describe '#report_sender' do
    let(:report) { described_class.new }
    subject { report.report_sender }
    before { allow(report).to receive(:user).and_return(user) }

    context 'messages are allotted' do
      before { allow(described_class).to receive(:messages_allotted?).with(user).and_return(true) }
      it do
        expect(User).to receive(:egotter).and_return('result')
        is_expected.to eq('result')
      end
    end

    context 'messages are not allotted' do
      before { allow(described_class).to receive(:messages_allotted?).with(user).and_return(false) }
      it { is_expected.to eq(user) }
    end
  end

  describe '#report_recipient' do
    let(:report) { described_class.new }
    subject { report.report_recipient }
    before { allow(report).to receive(:user).and_return(user) }

    context 'messages are allotted' do
      before { allow(described_class).to receive(:messages_allotted?).with(user).and_return(true) }
      it { is_expected.to eq(user) }
    end

    context 'messages are not allotted' do
      before { allow(described_class).to receive(:messages_allotted?).with(user).and_return(false) }
      it do
        expect(User).to receive(:egotter).and_return('result')
        is_expected.to eq('result')
      end
    end
  end
end
