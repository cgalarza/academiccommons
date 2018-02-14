class Api::SearchController < ActionController::Base

  # GET /api/v1/search(/:type_of_search)
  def search
    api_response = AcademicCommons::API.search(search_params)

    respond_to do |f|
      f.json { render json: api_response.body, status: api_response.status }
      f.rss  { render plain: api_response.body, status: api_response.status, content_type: 'application/rss+xml' }
      # f.rss  { render rss: api_response.body, status: api_response.status }
    end
  end

  def search_params
    filters = AcademicCommons::API::Search::VALID_FILTERS.map{ |f| [f, []] }.to_h
    params.permit(:type_of_search, :q, :page, :per_page, :format, :sort, :order, filters)
  end
end
