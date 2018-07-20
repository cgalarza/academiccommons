require 'rails_helper'

describe StatisticsController, type: :controller, integration: true do
  let(:pid) { 'actest:1' }

  describe 'GET detail_report' do
    include_examples 'authorization required' do
      let(:http_request) { get :detail_report }
    end
  end

  describe 'GET total_usage_stats' do
    context 'without being logged in' do
      before do
        allow(controller).to receive(:current_user).and_return(nil)
        get :total_usage_stats, params: { format: :json }
      end

      it 'returns 403' do # Can't redirect because its a json request.
        expect(response.status).to be 403
      end
    end

    context 'logged in as a non-admin user' do
      include_context 'non-admin user'

      it 'fails' do
        expect {
          get :total_usage_stats, params: { format: :json }
        }.to raise_error CanCan::AccessDenied
      end
    end

    context 'when admin user makes a request' do
      include_context 'admin user'

      before :each do
        FactoryBot.create(:view_stat)
        FactoryBot.create(:download_stat)
        FactoryBot.create(:streaming_stat)
      end

      subject { get :total_usage_stats, params: { q: "{!raw f=fedora3_pid_ssi}#{pid}", format: :json } }

      it 'return correct json response' do
        json = JSON.parse(subject.body)
        expect(json).to include(
          'view' => 1,
          'download' => 1,
          'streaming' => 1,
          'records' => 1
        )
      end
    end
  end

  describe 'GET common_statistics_csv' do
    include_examples 'authorization required' do
      let(:http_request) { get :common_statistics_csv, params: { f: { 'author_ssim' => ['Carroll, Lewis'] } } }
    end
  end

  describe 'GET generic_statistics' do
    include_examples 'authorization required' do
      let(:http_request) { get :generic_statistics }
    end
  end

  describe 'GET school_statistics' do
    include_examples 'authorization required' do
      let(:http_request) { get :school_statistics }
    end
  end

  describe 'GET send_csv_report' do
    include_examples 'authorization required' do
      let(:http_request) do
        get :send_csv_report,
            params: {
              f: { 'author_ssim' => ['Carroll, Lewis'] },
              email_to: 'example@example.com',
              email_from: 'me@example.com'
            }
      end
    end

    context 'when admin makes request' do
      include_context 'admin user'

      before do
        get :send_csv_report,
            params: {
              f: { 'author_ssim' => ['Carroll, Lewis.'] },
              email_to: 'example@example.com',
              email_from: 'me@example.com'
            }
      end

      it 'sends email' do
        email = ActionMailer::Base.deliveries.pop
        expect(email.to).to include 'example@example.com'
        expect(email.from).to include 'me@example.com'
      end
    end
  end

  # Does not require user login.
  describe 'GET unsubscribe_monthly' do
    let(:uni) { 'abc123' }
    context 'does not add email preference' do
      it 'when author missing' do
        get :unsubscribe_monthly, params: { chk: 'foo' }
        expect(EmailPreference.count).to eq 0
      end

      it 'when chk missing' do
        get :unsubscribe_monthly, params: { author_id: 'foo' }
        expect(EmailPreference.count).to eq 0
      end

      it 'when chk and author missing' do
        get :unsubscribe_monthly
        expect(EmailPreference.count).to eq 0
      end
    end

    context 'when chk param is correctly signed' do
      before :each do
        get :unsubscribe_monthly, params: { author_id: uni, chk: Rails.application.message_verifier(:unsubscribe).generate(uni) }
      end

      it 'creates email preference' do
        expect(EmailPreference.count).to eq 1
      end

      it 'unsubscribes user' do
        expect(EmailPreference.first.author).to eq uni
        expect(EmailPreference.first.monthly_opt_out).to be true
      end

      it 'changes email preference' do
        EmailPreference.first.update!(monthly_opt_out: false)
        get :unsubscribe_monthly, params: { author_id: uni, chk: Rails.application.message_verifier(:unsubscribe).generate(uni) }
        expect(EmailPreference.first.monthly_opt_out).to be true
      end
    end

    context 'when check param is not correctly signed' do
      before(:each) do
        get :unsubscribe_monthly, params: { author_id: uni, chk: Rails.application.message_verifier(:unsubscribe).generate('abc') }
      end

      it 'does not unsubscribe user' do
        expect(EmailPreference.count).to eq 0
      end
    end
  end
end
