class Statistic < ApplicationRecord
  YEAR_BEG = 2011 # first year we have statistics for.

  VIEW = 'View'.freeze
  DOWNLOAD = 'Download'.freeze
  STREAM = 'Streaming'.freeze

  EVENTS = [VIEW, DOWNLOAD, STREAM].freeze

  # Calculate the number of times the event given has occured for all the given
  # ids. If start and end date are given, the query is limited to that time period.
  # When querying with dates, timestamps are ignored.
  #
  # @note When querying for downloads asset ids must be used, not aggregator ids.
  #
  # @param [Array<String>|String] ids
  # @param [String] event
  # @param [Date|Time] start_date
  # @param [Date|Time] end_date
  # @return [Hash<String,Integer>] keys are ids and the value is the number of times said event occured
  def self.event_count(ids, event, start_date: nil, end_date: nil)
    # Check parameters.
    ids = [ids] if ids.is_a? String

    raise 'ids must be an Array or String' unless ids.is_a? Array
    raise "event must one of #{EVENTS}"    unless valid_event?(event)

    if start_date || end_date
      if start_date.respond_to?(:to_time) && end_date.respond_to?(:to_time)
        start_date = start_date.to_time.beginning_of_day
        end_date = end_date.to_time.end_of_day
        ids.each_slice(5000).each_with_object({}) do |identifiers, hash|
          hash.merge!(
            group(:identifier).where('identifier IN (?) and event = ? AND at_time BETWEEN ? and ?', identifiers, event, start_date, end_date).count
          )
        end
      else
        raise 'start_date and end_date must respond to :to_time'
      end
    else
      ids.each_slice(5000).each_with_object({}) do |identifiers, hash|
        hash.merge!(group(:identifier).where('identifier IN (?) and event = ?', identifiers, event).count)
      end
    end
  end

  def self.valid_event?(e)
    EVENTS.include?(e)
  end

  def self.merge_stats(pid, duplicate_pid)
    stats = Statistic.where(identifier: duplicate_pid)
    stats.each { |stat| stat.update!(identifier: pid) }
  end

  def self.reset_downloads
    Statistic.where(event: 'Download').each { |e| e.delete }

    fedora_download_match = /^([\d\.]+).+\[([^\]]+)\].+download\/fedora_content\/\w+\/([^\/]+)/
    startdate = DateTime.parse('5/1/2011')

    File.open(File.join('tmp', 'access.log')).each_with_index do |line, i|
      if (match = fedora_download_match.match(line))
        pid = match[3].gsub('%3A', ':')
        datetime = DateTime.parse(match[2].sub(':', ' '))
        ip = match[1]

        if pid.include?('ac')
          Statistic.create!(event: 'Download', ip_address: ip, identifier: pid, at_time: datetime)
        end
      end
    end
  end
end
