class CreateSyncRuns < ActiveRecord::Migration[8.1]
  def change
    # One row per programme sync attempt, written by ProgrammeSync.
    create_table :sync_runs do |t|
      t.string :status, null: false
      t.jsonb :request_params, null: false, default: {}
      t.jsonb :counts, null: false, default: {}
      t.jsonb :failures, null: false, default: []
      t.jsonb :missing_upstream, null: false, default: []
      t.text :error
      t.datetime :finished_at

      t.timestamps
    end
  end
end
