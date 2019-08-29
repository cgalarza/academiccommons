module AcademicCommons
  class SearchParameters
    MAX_ROWS = 100_000

    attr_reader :parameters

    def initialize
      @parameters = {
        qt: 'search',
        fq: [],
        rows: MAX_ROWS
      }
    end

    def q(q)
      @parameters[:q] = q
      self
    end

    def id(id)
      filter('id', id)
      self
    end

    def filter(key, value)
      @parameters[:fq] << if value.start_with?('(', '[') && value.end_with?(']', ')')
                            "#{key}:#{value}"
                          else
                            "#{key}:\"#{value}\""
                          end

      self
    end

    def assets_only
      filter('has_model_ssim', "(\"#{GenericResource.to_class_uri}\" OR \"#{::Resource.to_class_uri}\")")
      self
    end

    def aggregators_only
      filter('has_model_ssim', ContentAggregator.to_class_uri)
      self
    end

    def embargoed_only
      filter('object_state_ssi', 'A')
      @parameters[:fq] << 'free_to_read_start_date_dtsi:[NOW+1DAYS TO *]'
    end

    def rows(rows)
      @parameters[:rows] = rows
      self
    end

    def member_of(pid); end

    def fedora3_pid(pid); end

    def facet_by(*fields)
      @parameters[:facet] = true
      @parameters[:'facet.field'] = fields
      self
    end

    def facet_limit(limit)
      @parameters[:'facet.limit'] = limit
      self
    end

    # Only returns fields specified, the default behavior is to return all the
    # fields. Modifies the :fl solr parameter. Use carefully! This limits the
    # fields returned and could lead to unintended results.
    def field_list(*fields)
      @parameters[:fl] = Array.wrap(fields).join(',')
      self
    end

    def sort_by(sort)
      @parameters[:sort] = sort
      self
    end

    def to_h
      parameters
    end
  end
end
