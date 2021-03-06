module V1
  module Entities
    class Parameters < Grape::Entity
      %i[q sort order search_type].each do |key|
        expose key
      end

      expose :filters do
        V1::Helpers::Solr::FILTERS.each do |filter|
          expose filter, expose_nil: false
        end
      end
    end

    class SearchResponse < Grape::Entity
      expose :total_number_of_results do |solr_response, _options|
        solr_response.dig('response', 'numFound')
      end

      expose :per_page do |_solr_response, options|
        options[:params][:per_page]
      end

      expose :page do |_solr_response, options|
        options[:params][:page]
      end

      expose :params, using: Parameters do |_solr_response, options|
        options[:params]
      end

      expose :records, using: ShortRecord do |solr_response, _options|
        solr_response.docs
      end

      expose :facets do |solr_response, _options|
        facet_fields = solr_response.dig('facet_counts', 'facet_fields')
        facet_fields = {} if facet_fields.blank?

        V1::Helpers::Solr::FACETS.each_with_object({}) do |facet, hash|
          fields = facet_fields[V1::Helpers::Solr::MAP_TO_SOLR_FIELD[facet]]
          hash[facet] = Hash[*fields] if fields.present?
        end
      end
    end
  end
end
