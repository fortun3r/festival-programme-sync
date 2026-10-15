require "rails_helper"

RSpec.describe ProgrammeSyncJob do
  it "runs the programme sync" do
    stub_festival_api

    run = described_class.perform_now("generation" => "2")

    expect(run).to be_succeeded
    expect(Screening.count).to eq(61)
  end

  it "raises when the sync fails, so Sidekiq retries it" do
    stub_festival_api

    expect { described_class.perform_now("fail_after" => "8") }.to raise_error(FestivalApi::Error)
    expect(SyncRun.last).to be_failed
  end
end
