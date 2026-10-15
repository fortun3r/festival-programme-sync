class ScreeningsController < ApplicationController
  def index
    @venues = Venue.order(:name)

    @screenings = Screening.includes(:film, :venue).order(:starts_at)
    @screenings = @screenings.where(venue_id: params[:venue_id]) if params[:venue_id].present?
    query = params[:q].to_s.strip
    @screenings = @screenings.title_matching(query) if query.present?

    if params[:date].present?
      date = begin
        Date.parse(params[:date])
      rescue ArgumentError
        nil
      end
      @screenings = @screenings.where(starts_at: date.all_day) if date
    end
  end
end
