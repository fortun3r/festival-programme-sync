require "rails_helper"

RSpec.describe VenueSync do
  describe "#call" do
    it "creates a venue that doesn't exist yet" do
      payload = [
        { "id" => "VEN-01", "name" => "Grand Cinema", "address" => "12 Main Street", "capacity" => 320 }
      ]

      expect { VenueSync.new(payload).call }.to change(Venue, :count).by(1)

      venue = Venue.find_by(external_id: "VEN-01")
      expect(venue).to have_attributes(
        name: "Grand Cinema",
        address: "12 Main Street",
        capacity: 320
      )
    end

    it "updates the existing venue when upstream renames it" do
      venue = create(:venue, external_id: "VEN-03", name: "City Gallery Screening Room")
      payload = [
        { "id" => "VEN-03", "name" => "City Gallery Auditorium", "address" => "1 Museum Square", "capacity" => 90 }
      ]

      expect { VenueSync.new(payload).call }.not_to change(Venue, :count)
      expect(venue.reload.name).to eq("City Gallery Auditorium")
    end

    it "creates a new venue when upstream reuses an existing venue's name" do
      existing = create(:venue, external_id: "VEN-01", name: "Grand Cinema")
      payload = [
        { "id" => "VEN-07", "name" => "Grand Cinema", "address" => "5 New Road", "capacity" => 100 }
      ]

      expect { VenueSync.new(payload).call }.to change(Venue, :count).by(1)
      expect(existing.reload.external_id).to eq("VEN-01")
    end
  end
end
