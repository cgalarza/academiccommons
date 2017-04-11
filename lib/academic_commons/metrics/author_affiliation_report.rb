require 'csv'

module AcademicCommons::Metrics
  module AuthorAffiliationReport
    def self.generate_csv(current_user = nil)
      # Usage stats for all items
      solr_params = { q: nil } # sort by id?

      usage_stats = UsageStatistics.new(solr_params)

      headers = [
        'pid', 'persistent url', 'lifetime downloads', 'lifetime views',
        'department ac', 'genre', 'creation date', 'multi-author count',
        'author uni', 'author name', 'ldap author title',
        'ldap organizational unit'
      ]

      ldap_user = {} # Caching ldap user details.
      rows = []
      usage_stats.each do |item_stats|
        # retrieve entire solr document
        begin
          doc = Blacklight.default_index.find(item_stats.id).docs.first
        rescue Blacklight::Exceptions::RecordNotFound => e
          Rails.logger.warn("Document not found for #{item_stats.id}")
          next
        end

        start_of_row = [
          doc[:id],
          doc[:handle],
          item_stats.get_stat(Statistic::DOWNLOAD, UsageStatistics::LIFETIME),
          item_stats.get_stat(Statistic::VIEW, UsageStatistics::LIFETIME),
          doc.fetch(:department_facet, []).join(", "),
          doc.fetch(:genre_facet, []).join(", "),
          doc[:system_create_dtsi]
        ]

        author_count = 1

        # For each author_uni add a row...
        doc.fetch(:author_uni, []).each do |uni|
          row = CSV::Row.new(headers, start_of_row)

          row['author uni'] = uni
          row['multi-author count'] = author_count

          # query ldap for more information about this author
          person = ldap_user.fetch(uni, nil)
          if person.nil?
            person = AcademicCommons::LDAP.find_by_uni(uni)
            ldap_user[uni] = person
          end

          row['author name'] = person.name
          row['ldap author title'] = person.title
          row['ldap organizational unit'] = person.organizational_unit

          author_count += 1

          rows.append(row)
        end

        # For each author that does not have a author, row with just basic item information
        total_authors = doc.fetch(:author_facet, []).count
        while(total_authors >= author_count) do
          row = CSV::Row.new(headers, start_of_row)
          row['multi-author count'] = author_count

          author_count += 1
          rows.append(row)
        end

      end

      timestamp = Time.now.localtime.strftime('%FT%R')

       csv =  CSV.generate_line(['Author Affiliation Report'])
       csv << CSV.generate_line(['Report Generated By:', current_user || 'N/A', 'Report Generated:', timestamp])
       csv << CSV.generate_line([])
       csv << CSV::Table.new(rows).to_s
       csv
    end
  end
end
