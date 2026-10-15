namespace :programme do
  desc 'Sync the festival programme now and print what it did, e.g. bin/rails "programme:sync[generation=2&fail_after=8]"'
  task :sync, [ :query ] => :environment do |_task, args|
    # The optional argument is passed to the API as query params.
    sync = ProgrammeSync.new(Rack::Utils.parse_query(args[:query]))
    sync.call
  ensure
    puts sync.run.summary if sync&.run
  end
end
