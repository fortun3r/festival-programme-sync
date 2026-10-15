module FestivalApiHelpers
  # Serve FestivalApi requests from the app's own mock API, in-process, so
  # specs go through its real pagination, generations and failure modes.
  def stub_festival_api
    # WebMock 3.26 hands the app a plain Hash as rack.session, which Rails'
    # session middleware can't use (fixed in 3.28); drop it so Rails makes its own.
    app = ->(env) { Rails.application.call(env.except("rack.session", "rack.session.options")) }
    stub_request(:get, %r{/mock_api/screenings}).to_rack(app)
  end

  # A single page holding exactly `records`, for shapes the mock never produces.
  def stub_festival_page(records, total_count: records.size)
    stub_request(:get, %r{/mock_api/screenings}).to_return_json(
      body: { page: 1, per_page: 25, total_pages: 1, total_count: total_count, screenings: records }
    )
  end
end

RSpec.configure do |config|
  config.include FestivalApiHelpers
end
