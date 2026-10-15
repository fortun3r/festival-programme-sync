require "rails_helper"

RSpec.describe FestivalApi do
  subject(:api) { described_class.new }

  describe "#screenings_page" do
    it "returns a page of screenings with the film and venue nested" do
      stub_festival_api

      page = api.screenings_page(1)

      expect(page).to include("page" => 1, "total_pages" => 3, "total_count" => 60)
      expect(page["screenings"].size).to eq(25)
      expect(page["screenings"].first).to include(
        "id" => "SCR-0001",
        "film" => hash_including("id" => "FILM-001"),
        "venue" => hash_including("id" => "VEN-01")
      )
    end

    it "passes params through to the API" do
      stub_festival_api

      expect(api.screenings_page(3, "generation" => "2")).to include("total_count" => 61)
    end

    it "raises FestivalApi::Error naming the page when the API errors" do
      stub_festival_api

      expect { api.screenings_page(2, "fail_after" => "8") }.to raise_error(FestivalApi::Error, /\Apage 2: .*500/)
    end

    it "raises FestivalApi::Error when the API can't be reached" do
      stub_request(:get, %r{/mock_api/screenings}).to_timeout

      expect { api.screenings_page(1) }.to raise_error(FestivalApi::Error, /\Apage 1: /)
    end

    it "raises FestivalApi::Error when the response isn't a page of screenings" do
      stub_request(:get, %r{/mock_api/screenings})
        .to_return(status: 200, body: "<html>Down for maintenance</html>", headers: { "Content-Type" => "text/html" })

      expect { api.screenings_page(1) }.to raise_error(FestivalApi::Error, "page 1: unexpected response body")
    end
  end
end
