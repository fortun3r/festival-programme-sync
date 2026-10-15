require "rails_helper"

RSpec.describe Screening do
  describe ".title_matching" do
    it "matches part of the film title, ignoring case" do
      autumn = create(:screening, film: create(:film, title: "Autumn in Trieste"))
      create(:screening, film: create(:film, title: "Paper Boats"))

      expect(Screening.title_matching("autumn")).to contain_exactly(autumn)
    end

    it "treats % and _ in the search as plain characters" do
      percent = create(:screening, film: create(:film, title: "100% Fiction"))
      create(:screening, film: create(:film, title: "1000 Nights"))

      expect(Screening.title_matching("100%")).to contain_exactly(percent)
      expect(Screening.title_matching("_")).to be_empty
    end
  end
end
