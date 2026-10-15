require "rails_helper"

RSpec.describe SyncRun do
  describe "#summary" do
    it "says what a finished run did" do
      run = SyncRun.create!(
        status: :succeeded,
        request_params: { "generation" => "2" },
        counts: {
          "screenings" => { "created" => 2, "updated" => 7, "unchanged" => 52 },
          "films" => { "created" => 0, "updated" => 1, "unchanged" => 11 },
          "venues" => { "created" => 0, "updated" => 1, "unchanged" => 5 },
          "failed" => 0,
          "missing_upstream" => 1
        },
        missing_upstream: [ "SCR-0060" ]
      )

      expect(run.summary).to eq(
        "Sync run ##{run.id} (generation=2) succeeded — screenings: 2 created, 7 updated, 52 unchanged; " \
        "films: 0 created, 1 updated, 11 unchanged; venues: 0 created, 1 updated, 5 unchanged; " \
        "failed: 0; missing upstream: 1 (SCR-0060)"
      )
    end

    it "gives the reason when a run ended before syncing anything" do
      run = SyncRun.create!(status: :failed, error: "FestivalApi::Error: page 1: execution expired")

      expect(run.summary).to eq("Sync run ##{run.id} failed: FestivalApi::Error: page 1: execution expired")
    end
  end
end
