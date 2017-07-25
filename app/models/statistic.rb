class Statistic < ActiveRecord::Base
  VIEW = 'View'
  DOWNLOAD = 'Download'
  STREAM = 'Streaming'

  EVENTS = [VIEW, DOWNLOAD, STREAM]

  # Calculate the number of times the event given has occured for all the given
  # pids. If start and end date are given, the query is limited to that time period.
  # When querying with dates, time stamps are ignored.
  #
  # @note When querying for downloads asset pids must be used, not aggregator pids.
  #
  # @param [Array<String>|String] pids
  # @param [String] event
  # @param [Date] start_date
  # @param [Date] end_date
  # @return [Hash<String,Integer>] keys are ids and the value is the number of times said event occured
  def self.event_count(pids, event, start_date: nil, end_date: nil)
    # Check parameters.
    pids = [pids] if pids.is_a? String

    raise 'pids must be an Array or String' unless pids.is_a? Array
    raise "event must one of #{EVENTS}"     unless valid_event?(event)

    if start_date || end_date
      if start_date.respond_to?(:to_time) && end_date.respond_to?(:to_time)
        start_date = start_date.to_time.beginning_of_day
        end_date = end_date.to_time.end_of_day
        group(:identifier).where("identifier IN (?) and event = ? AND at_time BETWEEN ? and ?", pids, event, start_date, end_date).count
      else
        raise 'start_date and end_date must respond to :to_time'
      end
    else
      group(:identifier).where("identifier IN (?) and event = ?", pids, event).count
    end
  end

  def self.valid_event?(e)
    EVENTS.include?(e)
  end

  def self.merge_stats(pid, duplicate_pid)
     logger.warn "Merging statistics for #{duplicate_pid} with #{pid}..."

     # Retrive solr document for both and check that they are both the same type
     document = ActiveFedora::SolrService.query("{!raw f=id}#{pid}").first
     duplicate_document = ActiveFedora::SolrService.query("{!raw f=id}#{duplicate_pid}").first

     unless document['active_fedora_model_ssi'] == duplicate_document['active_fedora_model_ssi']
       raise 'Records cannot be migrated because they are not of the same type.'
     end

     # Get all the stats records for duplicate_pid, update the identifier to be pid
     stats = Statistic.where(identifier: duplicate_pid)
     logger.warn "Duplicated record (#{duplicate_pid}) has #{stats.count} statistics."
     logger.warn "Merging stats..."
     stats.each { |stat| stat.update!(identifier: pid) }
     logger.warn "Duplicate record has #{Statistic.where(identifier: duplicate_pid).count} stats"
  end

  def self.reset_downloads
    Statistic.where(:event => "Download").each { |e| e.delete }

    fedora_download_match = /^([\d\.]+).+\[([^\]]+)\].+download\/fedora_content\/\w+\/([^\/]+)/
    startdate = DateTime.parse("5/1/2011")

    File.open(File.join("tmp", "access.log")).each_with_index do |line, i|

      if (match = fedora_download_match.match(line))
        pid = match[3].gsub("%3A", ":")
        datetime = DateTime.parse(match[2].sub(":", " "))
        ip = match[1]

        if pid.include?("ac")
          Statistic.create!(:event => "Download", :ip_address => ip, :identifier => pid, :at_time => datetime)
        end
      end
    end
  end
end
