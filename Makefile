.PHONY: up build down console sh test sync logs reset psql

# Start everything (Postgres, Redis, web, css watcher, sidekiq).
up:
	docker compose up

# Rebuild images then start (use after changing the Gemfile or Dockerfile).
build:
	docker compose up --build

# Stop and remove containers (keeps the database volume).
down:
	docker compose down

# Rebuild Tailwind CSS after editing view classes (the watcher can't see host
# edits over the Docker mount, so rebuild on demand).
css:
	docker compose exec web bin/rails tailwindcss:build

# Rails console inside the running web container.
console:
	docker compose exec web bin/rails console

# A bash shell inside the running web container.
sh:
	docker compose exec web bash

# Run the RSpec suite against a freshly prepared test database.
test:
	docker compose run --rm -e RAILS_ENV=test web sh -c "bin/rails db:prepare && bundle exec rspec"

# Run the programme sync now and print what it did. Pass the API's query params
# quoted, e.g. make sync Q='generation=2&fail_after=8'
sync:
	docker compose exec web bin/rails "programme:sync[$(Q)]"

# Follow the web + sidekiq logs.
logs:
	docker compose logs -f web sidekiq

# psql into the development database.
psql:
	docker compose exec db psql -U postgres -d festival_development

# Nuke everything including the database volume, then rebuild from scratch.
reset:
	docker compose down -v
	docker compose up --build
