# frozen_string_literal: true

namespace :dev do
  desc "Start the Rails server and Tailwind CSS watcher"
  task :start do
    puts "Starting development servers..."
    puts "Press Ctrl+C to stop all servers"
    puts ""

    # Start foreman with Procfile.dev using bundle exec
    exec("bundle exec foreman start -f Procfile.dev")
  end
end

