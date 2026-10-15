class Screening < ApplicationRecord
  belongs_to :film
  belongs_to :venue

  enum :status, { scheduled: "scheduled", cancelled: "cancelled" }, default: "scheduled"

  scope :title_matching, ->(query) { where(film: Film.where("title ILIKE ?", "%#{sanitize_sql_like(query)}%")) }

  validates :external_id, presence: true, uniqueness: true
  validates :starts_at, presence: true
end
