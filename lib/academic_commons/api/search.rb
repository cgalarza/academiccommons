module AcademicCommons::API
  class Search
    VALID_SEARCH_TYPES = %w(keyword title subject)
    VALID_FILTERS = %w(author author_id date department subject type series)
    VALID_SORT    = %w(best_match date title created_at)
    VALID_FORMATS = %w(json rss)
    VALID_ORDER   = %w(desc asc)
    REQUIRED_FILTERS = ["has_model_ssim:\"#{ContentAggregator.to_class_uri}\""]
    KEY_TO_SOLR_FIELD = SolrDocument.field_semantics

    SEARCH_TYPES_TO_QUERY = {
      'title' => {'spellcheck.dictionary': 'title', qf: '${title_qf}', pf: '${title_pf}'},
      'subject' => {'spellcheck.dictionary': 'subject', qf: '${subject_qf}', pf: '${subject_pf}'}
    }

    MAX_PER_PAGE = 100

    SORT_TO_SOLR_SORT = {
      'best_match' => {
        'asc'  => 'score desc, pub_date_sort desc, title_sort asc',
        'desc' => 'score desc, pub_date_sort desc, title_sort asc'
      },
      'date' => {
        'asc'  => 'pub_date_sort asc, title_sort asc',
        'desc' => 'pub_date_sort desc, title_sort asc'
      },
      'title' => {
        'asc'  => 'title_sort asc, pub_date_sort desc',
        'desc' => 'title_sort desc, pub_date_sort desc'
      }
    }

    DEFAULT_PARAMS = {
      search_type: 'keyword',
      page: 1,
      per_page: 25,
      format: 'json',
      sort: 'best_match',
      order: 'desc'
    }

    attr_reader :parameters, :errors, :response

    # Returns response object
    def initialize(params)
      @parameters = params
      @errors = []

      @response = if params_valid?
                    @parameters = parameters.reverse_merge(DEFAULT_PARAMS)
                    connection = AcademicCommons::Utils.rsolr
                    solr_response = connection.get('select', params: solr_parameters)
                    SuccessResponse.new(parameters, solr_response: solr_response)
                  else
                    ErrorResponse.new(parameters[:format], errors, :bad_request)
                  end
    end

    private

    def solr_parameters
       filters = VALID_FILTERS.map do |filter|
         parameters.fetch(filter, []).map { |value| "#{KEY_TO_SOLR_FIELD[filter.to_sym]}:\"#{value}\"" }
       end.flatten

      solr_params = {
        q: parameters[:q],
        sort: SORT_TO_SOLR_SORT[parameters[:sort]][parameters[:order]],
        start: (parameters[:page].to_i - 1) * parameters[:per_page].to_i,
        rows: parameters[:per_page].to_i,
        fq: ["has_model_ssim:\"#{ContentAggregator.to_class_uri}\""].concat(filters),
        fl: '*', # default blacklight solr param
        qt: 'search' # default blacklight solr param
      }

      if SEARCH_TYPES_TO_QUERY.key? parameters[:search_type]
        solr_params.merge!(SEARCH_TYPES_TO_QUERY[parameters[:search_type]])
      end
      puts solr_params

      solr_params
    end

    def params_valid?
      valid_value(:search_type, VALID_SEARCH_TYPES)
      valid_value(:sort, VALID_SORT)
      valid_value(:format, VALID_FORMATS)
      valid_value(:order, VALID_ORDER)

      valid_number(:per_page)
      valid_number(:page)

      value_not_greater_than(:per_page, MAX_PER_PAGE)

      @errors.empty?
    end

    ## Validation methods. Potentially move them into their own class.
    def valid_value(field, valid_values)
      return if parameters[field].blank? || valid_values.include?(parameters[field])
      @errors << "Invalid value for #{field}"
    end

    def valid_number(field)
      return if parameters[field].blank? || (/^\d+$/ === parameters[field] && !parameters[field].to_i.zero?)
      @errors << "Invalid number value for #{field}"
    end

    def value_not_greater_than(field, max_value)
      return if parameters[field].blank? || parameters[field].to_i <= max_value
      @errors << "Invalid value for #{field}. Maximum accepted value #{max_value}"
    end
  end
end