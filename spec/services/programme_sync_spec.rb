require "rails_helper"

# Runs against the app's own mock API (see FestivalApiHelpers). No factories
# here: their ids would collide with the mock dataset's.
RSpec.describe ProgrammeSync do
  def sync(params = {})
    ProgrammeSync.new(params).call
  end

  it "imports the whole programme into an empty database" do
    stub_festival_api

    run = sync

    expect(run).to be_succeeded
    expect([ Screening.count, Film.count, Venue.count ]).to eq([ 60, 12, 6 ])
    expect(run.counts).to eq(
      "screenings" => { "created" => 60, "updated" => 0, "unchanged" => 0 },
      "films" => { "created" => 12, "updated" => 0, "unchanged" => 0 },
      "venues" => { "created" => 6, "updated" => 0, "unchanged" => 0 },
      "failed" => 0,
      "missing_upstream" => 0
    )
    expect(Screening.find_by!(external_id: "SCR-0001")).to have_attributes(
      film: Film.find_by!(external_id: "FILM-001"),
      venue: Venue.find_by!(external_id: "VEN-01"),
      status: "scheduled"
    )
  end

  it "writes nothing when run again on the same data" do
    stub_festival_api
    sync

    second = nil
    expect { second = sync }
      .not_to change { [ Screening, Film, Venue ].map { |model| [ model.count, model.maximum(:updated_at) ] } }
    expect(second.counts).to include(
      "screenings" => { "created" => 0, "updated" => 0, "unchanged" => 60 },
      "films" => { "created" => 0, "updated" => 0, "unchanged" => 12 },
      "venues" => { "created" => 0, "updated" => 0, "unchanged" => 6 }
    )
  end

  it "applies upstream changes to the existing rows" do
    stub_festival_api
    sync
    film = Film.find_by!(external_id: "FILM-005")
    venue = Venue.find_by!(external_id: "VEN-03")

    run = sync("generation" => "2")

    expect(run).to be_succeeded
    expect(film.reload.title).to eq("Autumn in Trieste (Director's Cut)")
    expect(venue.reload.name).to eq("City Gallery Auditorium")
    expect([ Film.count, Venue.count ]).to eq([ 12, 6 ])
    expect(Screening.find_by!(external_id: "SCR-0001").venue.external_id).to eq("VEN-06")
    expect(Screening.where(external_id: %w[ SCR-0010 SCR-0011 SCR-0012 ])).to all(be_cancelled)
    expect(Screening.where(external_id: %w[ SCR-0061 SCR-0062 ]).count).to eq(2)
    expect(run.counts).to include(
      "screenings" => { "created" => 2, "updated" => 7, "unchanged" => 52 },
      "films" => { "created" => 0, "updated" => 1, "unchanged" => 11 },
      "venues" => { "created" => 0, "updated" => 1, "unchanged" => 5 },
      "missing_upstream" => 1
    )
    # Gone upstream: reported, not deleted.
    expect(run.missing_upstream).to eq([ "SCR-0060" ])
    expect(Screening.exists?(external_id: "SCR-0060")).to be(true)
  end

  it "keeps what it saved when the API fails part-way, and the next run finishes the job" do
    stub_festival_api

    expect { sync("fail_after" => "8") }.to raise_error(FestivalApi::Error, /page 2/)

    failed = SyncRun.last
    expect(failed).to be_failed
    expect(failed.error).to match(/page 2: .*500/)
    expect(failed.counts["screenings"]).to eq("created" => 8, "updated" => 0, "unchanged" => 0)
    expect(Screening.count).to eq(8)

    run = sync
    expect(run).to be_succeeded
    expect(run.counts).to include(
      "screenings" => { "created" => 52, "updated" => 0, "unchanged" => 8 },
      "films" => { "created" => 4, "updated" => 0, "unchanged" => 8 }
    )
  end

  it "loses nothing when a later run fails part-way" do
    stub_festival_api
    sync

    expect { sync("fail_after" => "8") }.to raise_error(FestivalApi::Error)

    expect(Screening.count).to eq(60)
    expect(SyncRun.last.missing_upstream).to be_empty
  end

  it "flags a run that received fewer screenings than the API reported" do
    stub_festival_api
    sync

    # The last page comes back short with a 200: no error to catch.
    run = sync("fail_after" => "55")

    expect(run).to be_completed_with_errors
    expect(run.error).to eq("Received 55 of 60 screenings")
    expect(run.missing_upstream).to be_empty
  end

  it "skips bad records, saying why, and saves the rest" do
    good = MockApi::Dataset.generation_one.first(2)
    template = good.first
    stub_festival_page([
      good.first,
      nil,
      template.merge("id" => "SCR-0901").except("film"),
      template.merge("id" => "SCR-0902", "film" => template["film"].merge("id" => "FILM-901", "title" => "")),
      template.merge("id" => "SCR-0903", "starts_at" => "not a date"),
      good.last
    ])

    run = sync

    expect(run).to be_completed_with_errors
    expect(Screening.pluck(:external_id)).to contain_exactly("SCR-0001", "SCR-0002")
    expect(Film.exists?(external_id: "FILM-901")).to be(false)
    expect(run.counts["screenings"]).to eq("created" => 2, "updated" => 0, "unchanged" => 0)
    expect(run.counts["failed"]).to eq(4)
    expect(run.failures.pluck("external_id")).to eq([ nil, "SCR-0901", "SCR-0902", "SCR-0903" ])
    expect(run.failures.pluck("error")).to all(be_present)
    # The record without an id can't be accounted for, so the run can't vouch
    # that it saw everything upstream has.
    expect(run.error).to eq("Received 5 of 6 screenings")
  end

  it "counts a screening served twice in one run once" do
    record = MockApi::Dataset.generation_one.first
    # Offset paging repeats a record when upstream inserts one mid-run.
    stub_festival_page([ record, record ], total_count: 1)

    run = sync

    expect(run).to be_succeeded
    expect(run.counts["screenings"]).to eq("created" => 1, "updated" => 0, "unchanged" => 0)
  end

  it "only passes the API params it knows, so a stray page can't break paging" do
    stub_festival_api

    run = sync("generation" => "2", "page" => "3")

    expect(run.request_params).to eq("generation" => "2")
    expect(Screening.count).to eq(61)
  end
end
