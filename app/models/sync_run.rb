# One row per programme sync attempt: what was asked for, how it ended and
# what it changed. Written by ProgrammeSync.
class SyncRun < ApplicationRecord
  enum :status, {
    running: "running",
    succeeded: "succeeded",
    completed_with_errors: "completed_with_errors",
    failed: "failed",
    skipped: "skipped"
  }

  # One line for the logs and the rake task.
  def summary
    line = [ "Sync run ##{id}", ("(#{request_params.to_query})" if request_params.present?), status ].compact.join(" ")
    line += ": #{error}" if error.present?
    return line if counts.blank?

    tallies = %w[ screenings films venues ].map do |kind|
      "#{kind}: " + %w[ created updated unchanged ].map { |outcome| "#{counts.dig(kind, outcome)} #{outcome}" }.join(", ")
    end
    tallies << "failed: #{counts["failed"]}"
    tallies << "missing upstream: #{counts["missing_upstream"]}#{" (#{missing_upstream.join(", ")})" if missing_upstream.any?}"
    "#{line} — #{tallies.join("; ")}"
  end
end
