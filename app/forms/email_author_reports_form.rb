class EmailAuthorReportsForm < FormObject
  YEAR_BEG = 2011 # first year we have statistics for.
  MONTHS = Date::ABBR_MONTHNAMES.dup[1..12].freeze
  REPORTS_FOR_OPTIONS = ['one', 'all'].freeze
  ORDER_WORKS_BY_OPTIONS = ['titles', 'views', 'downloads'].freeze
  DELIVER_OPTIONS = ['reports_to_each_author', 'do_not_send_email', 'all_reports_to_one_email'].freeze

  attr_accessor :reports_for, :uni, :month, :year, :order_works_by,
                :optional_note, :deliver, :email
  attr_reader   :sent_counter, :skipped_counter, :sent_exceptions

  validates :reports_for, :month, :year, :order_works_by, :deliver, presence: true
  validates :email, presence: true, if: proc { |a| a.deliver == 'all_reports_to_one_email' }
  validates :uni,   presence: true, if: proc { |a| a.reports_for == 'one' }
  validates :year,  numericality: { greater_than_or_equal_to: YEAR_BEG, less_than_or_equal_to: Time.current.year }
  validates :deliver,        inclusion: { in: DELIVER_OPTIONS }
  validates :reports_for,    inclusion: { in: REPORTS_FOR_OPTIONS }
  validates :month,          inclusion: { in: MONTHS }
  validates :order_works_by, inclusion: { in: ORDER_WORKS_BY_OPTIONS }

  def send_emails
    return false unless valid?

    if monthly_reports_in_process?
      errors.add(:base, 'There is already an email process running.')
      return false
    else
      send_authors_reports
    end
  end

  def message
    "#{@sent_counter} #{'message'.pluralize(@sent_counter)} sent, #{@skipped_counter} #{'message'.pluralize(@skipped_counter)} skipped, #{@sent_exceptions} #{'error'.pluralize(@send_exceptions)}."
  end

  private

  def send_authors_reports
    start_time = Time.current
    time_id = start_time.strftime('%Y%m%d-%H%M%S')

    log_path = Rails.root.join('log', 'monthly_reports')
    reports_logger = ActiveSupport::Logger.new(File.join(log_path, "#{time_id}.tmp"))
    reports_logger.formatter = Rails.application.config.log_formatter

    reports_logger.info '=== All Authors Monthly Reports ==='
    reports_logger.info 'Started at: ' + start_time.xmlschema
    reports_logger.info 'Parameters:'
    %i[reports_for uni month year order_works_by optional_note deliver email].each do |key|
      value = send(key)
      reports_logger.info "\t#{key}: #{send(key)}" if value.present?
    end
    reports_logger.info

    @sent_counter = 0
    @skipped_counter = 0
    @sent_exceptions = 0

    startdate = Date.parse(month + ' ' + year)
    enddate   = Date.new(startdate.year, startdate.month, -1) # end_date needs to be last day of month

    authors.each do |author|
      begin
        author_id = author[:id]

        solr_params = { q: nil, fq: ["author_uni_ssim:\"#{author_id}\""] }
        usage_stats = AcademicCommons::Metrics::UsageStatistics.new(
          solr_params, startdate, enddate,
          order_by: order_works_by, include_zeroes: true, include_streaming: false
        )

        send_to = deliver == 'all_reports_to_one_email' ? email : author[:email]
        raise 'no email address found' if send_to.nil?

        if usage_stats.empty?
          @skipped_counter += 1
          reports_logger.info "Report for '#{author_id}' was skipped"
        elsif deliver == 'do_not_send_email'
          reports_logger.info "Report for '#{author_id}' would have been sent to #{send_to}, but NO EMAIL WAS SENT BECAUSE THIS IS A TEST."
          @skipped_counter += 1
        else
          Notifier.author_monthly(send_to, author_id, usage_stats, optional_note).deliver
          reports_logger.info "Report for '#{author_id}' was sent to #{send_to} at #{Time.current.xmlschema}."
          @sent_counter += 1
        end
      rescue StandardError => e
        reports_logger.error "For #{author_id}, email: #{author[:email]}"
        reports_logger.error "#{e}\n\t#{e.backtrace.join("\n\t")}"
        @sent_exceptions += 1
      end
    end

    finish_time = Time.current
    reports_logger.info
    reports_logger.info 'Number of emails'
    reports_logger.info "sent: #{@sent_counter}, skipped: #{@skipped_counter}, errors: #{@sent_exceptions}"
    reports_logger.info 'Finished at: ' + finish_time.xmlschema

    seconds_spent = finish_time - start_time
    readble_time_spent = Time.at(seconds_spent).utc.strftime('%H hours, %M minutes, %S seconds')

    reports_logger.info "Time spent: #{readble_time_spent}"

    File.rename(File.join(log_path, "#{time_id}.tmp"), File.join(log_path, "#{time_id}.log"))
    reports_logger.close

    true
  end

  def authors
    if reports_for == 'one'
      ids = [uni]
    else
      results = AcademicCommons.search do |params|
        params.field_list('author_uni_ssim')
      end

      ids = results.docs.map { |f| f['author_uni_ssim'] }.flatten.compact.uniq - EmailPreference.where(monthly_opt_out: true).map(&:author)
    end

    alternate_emails = {}

    EmailPreference.where('email is NOT NULL and monthly_opt_out = 0').each do |ep|
      alternate_emails[ep.author] = ep.email
    end

    ids.collect { |id| { id: id, email: alternate_emails[id] || "#{id}@columbia.edu" } }
  end

  def monthly_reports_in_process?
    Dir.glob(Rails.root.join('log', 'monthly_reports', '*.tmp')) do
      return true
    end
    false
  end
end
