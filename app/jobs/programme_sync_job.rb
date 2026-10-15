# Runs ProgrammeSync in the background. Scheduled hourly by sidekiq-cron
# (config/schedule.yml).
class ProgrammeSyncJob < ApplicationJob
  # The sync is idempotent, so retrying is safe. A few quick retries (all
  # within about two minutes) cover upstream blips, and the next hourly run
  # covers the rest. Sidekiq's default of 25 retries over about 20 days would
  # replay stale syncs long after newer ones succeeded.
  sidekiq_options retry: 3

  # Only an API or database failure raises (and so retries). Bad records and
  # a run skipped because another is in progress return normally.
  def perform(params = {})
    ProgrammeSync.new(params).call
  end
end
