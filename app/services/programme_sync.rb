# Pulls the festival programme (screenings, each with its film and venue) from
# the festival API into our local copy, and records the run as a SyncRun.
#
# Rows are matched on upstream ids, so running it again changes nothing and
# upstream edits (a retitled film, a renamed venue) update rows in place.
# Each record is saved on its own: a bad record is noted and skipped, and if
# the API fails part-way the run is marked failed but what was saved stays.
class ProgrammeSync
  # Query params the API takes besides page (generation/fail_after/slow drive the mock).
  API_PARAMS = %w[ generation fail_after slow ].freeze
  # How many failed records and missing ids a SyncRun keeps.
  LISTED = 50

  attr_reader :run

  def initialize(params = {}, api: FestivalApi.new)
    @params = params.to_h.stringify_keys.slice(*API_PARAMS)
    @api = api
  end

  def call
    @counts = %w[ screenings films venues ].index_with { { "created" => 0, "updated" => 0, "unchanged" => 0 } }
    @counts.merge!("failed" => 0, "missing_upstream" => 0)
    @failures = []
    @films = {}
    @venues = {}
    @seen = Set.new
    @run = SyncRun.create!(status: :running, request_params: @params)

    finish(sync_pages)
    @run
  rescue => e
    @run&.update!(status: :failed, error: "#{e.class}: #{e.message}", counts: @counts,
                  failures: @failures.first(LISTED), finished_at: Time.current)
    Rails.logger.error(@run.summary) if @run
    raise
  end

  private

  # Follows the page count the API reports instead of stopping at a short
  # page: a failing API can send a short page before it errors. Returns the
  # total the API reported on its last page.
  def sync_pages
    page = 1
    loop do
      body = @api.screenings_page(page, @params)
      body["screenings"].each { |record| sync_record(record) }
      @run.update!(counts: @counts, failures: @failures.first(LISTED))
      return body["total_count"] if page >= body["total_pages"]

      page += 1
    end
  end

  def sync_record(record)
    external_id = record["id"] if record.is_a?(Hash)
    # Offset pagination can serve a record twice if upstream changes mid-run.
    return if external_id && !@seen.add?(external_id)

    film = film_for(record.fetch("film"))
    venue = venue_for(record.fetch("venue"))
    upsert(Screening, record.fetch("id"),
           film: film, venue: venue, starts_at: record.fetch("starts_at"), status: record.fetch("status"))
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed
    raise # the database is gone, not this record: fail the run
  rescue StandardError => e
    # Upstream data is untrusted, so any other error is about this record:
    # note it and carry on with the rest of the batch.
    @counts["failed"] += 1
    @failures << { "external_id" => external_id, "error" => "#{e.class}: #{e.message}" }
  end

  # Films and venues repeat across screenings, so each is upserted once per
  # run, and only remembered once it has saved.
  def film_for(attributes)
    @films[attributes.fetch("id")] ||=
      upsert(Film, attributes.fetch("id"), attributes.slice("title", "synopsis", "runtime", "year"))
  end

  def venue_for(attributes)
    @venues[attributes.fetch("id")] ||=
      upsert(Venue, attributes.fetch("id"), attributes.slice("name", "address", "capacity"))
  end

  # Inserts or updates by external id, skipping the write when nothing
  # changed. Counted only once the write has succeeded.
  def upsert(model, external_id, attributes)
    record = model.find_or_initialize_by(external_id: external_id)
    record.assign_attributes(attributes)
    outcome = record.new_record? ? "created" : (record.changed? ? "updated" : "unchanged")
    record.save! unless outcome == "unchanged"
    @counts[model.table_name][outcome] += 1
    record
  end

  def finish(total)
    error = nil
    missing = []
    if @seen.size == total
      # Reported, not deleted: absence from one paged snapshot is weak evidence.
      missing = Screening.where.not(external_id: @seen.to_a).order(:external_id).pluck(:external_id)
      @counts["missing_upstream"] = missing.size
    else
      error = "Received #{@seen.size} of #{total} screenings"
    end

    status = (error || @counts["failed"].positive?) ? :completed_with_errors : :succeeded
    @run.update!(status: status, error: error, counts: @counts, failures: @failures.first(LISTED),
                 missing_upstream: missing.first(LISTED), finished_at: Time.current)
    Rails.logger.info(@run.summary)
  end
end
