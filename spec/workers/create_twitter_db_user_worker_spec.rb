require 'rails_helper'

RSpec.describe CreateTwitterDBUserWorker do
  let(:bot) { create(:bot) }
  let(:client) { bot.api_client }
  let(:user) { create(:user) }
  let(:uids) { [1, 2] }
  let(:worker) { CreateTwitterDBUserWorker.new }

  describe '#perform' do
    subject { worker.perform(uids, options) }

    context 'The options includes force_update' do
      let(:options) { {'force_update' => true} }
      it do
        expect(Bot).to receive(:api_client).with(no_args).and_return(client)
        expect(worker).to receive(:do_perform).with(uids, client, true, nil)
        subject
      end
    end

    context 'The options includes user_id' do
      let(:options) { {'user_id' => user.id} }
      before do
        allow(User).to receive_message_chain(:find, :api_client).with(user.id).with(no_args).and_return(client)
      end
      it do
        expect(Bot).not_to receive(:api_client)
        expect(worker).to receive(:do_perform).with(uids, client, nil, user.id)
        subject
      end
    end

    context "The options is empty" do
      let(:options) { {} }
      it do
        expect(Bot).to receive(:api_client).and_return(client)
        expect(worker).to receive(:do_perform).with(uids, client, nil, nil)
        subject
      end
    end
  end

  describe '#do_perform' do
    subject { worker.do_perform(uids, nil, false, user_id) }

    before do
      allow(TwitterDB::User::Batch).to receive(:fetch_and_import!).with(any_args).and_raise(exception)
    end

    context 'A exception is raised' do
      let(:user_id) { user.id }
      let(:exception) { RuntimeError.new('Something happened.') }

      it do
        expect(Bot).not_to receive(:api_client)
        expect { subject }.to raise_error(RuntimeError)
      end
    end

    context 'A retryable exception is raised and the valid user_id is passed' do
      let(:user_id) { user.id }
      let(:exception) { Twitter::Error::Unauthorized.new('Invalid or expired token.') }

      it do
        expect(Bot).to receive(:api_client).with(no_args)
        expect { subject }.to raise_error(Twitter::Error::Unauthorized)
      end
    end

    context 'A retryable exception is raised and the user_id is invalid' do
      let(:user_id) { nil }
      let(:exception) { Twitter::Error::Unauthorized.new('Invalid or expired token.') }

      it do
        expect(Bot).not_to receive(:api_client)
        expect { subject }.to raise_error(Twitter::Error::Unauthorized)
      end
    end
  end
end