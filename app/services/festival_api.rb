# Client for the festival-management system's API. In this app it's served by
# MockApi::ScreeningsController at FESTIVAL_API_URL.
class FestivalApi
  # The API couldn't give us a page: an HTTP error, a timeout, a dropped
  # connection, or a body that isn't a page of screenings.
  class Error < StandardError; end

  def initialize(base_url: ENV.fetch("FESTIVAL_API_URL", "http://localhost:3000"))
    # The API is sometimes slow (around 6s), but a hung request shouldn't hold a run forever.
    @http = Faraday.new(url: base_url, request: { open_timeout: 5, timeout: 15 }) do |f|
      f.response :json
      f.response :raise_error
    end
  end

  # One page of screenings, each with its film and venue nested. `params` are
  # passed through as query parameters.
  def screenings_page(page, params = {})
    body = @http.get("/mock_api/screenings", params.merge("page" => page)).body
    return body if body.is_a?(Hash) && body["screenings"].is_a?(Array) && body.values_at("total_pages", "total_count").all?(Integer)

    raise Error, "page #{page}: unexpected response body"
  rescue Faraday::Error => e
    raise Error, "page #{page}: #{e.message}"
  end
end
