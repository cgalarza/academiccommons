require 'rails_helper'

describe LogsController, type: :controller do
  describe 'GET ingest_history' do
    include_examples 'authorization required' do
      let(:http_request) { get :ingest_history }
    end
  end

  describe 'GET all_author_monthly_reports_history' do
    include_examples 'authorization required' do
      let(:http_request) { get :all_author_monthly_reports_history }
    end
  end

  describe 'GET log_form' do
    include_context 'log'

    include_examples 'authorization required' do
      let(:http_request) { get :log_form, params: { log_id: id, log_folder: 'ac-indexing' } }
    end
  end

  describe 'GET download_log' do
    include_context 'log'

    include_examples 'authorization required' do
      let(:http_request) { get :download_log, params: { log_folder: 'ac-indexing', id: id } }
    end
  end
end
