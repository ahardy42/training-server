# frozen_string_literal: true

namespace :docker do
  desc "Build Docker image for development"
  task :build_dev do
    puts "Building development Docker image..."
    system("docker-compose build") || abort("Build failed!")
    puts "Development build complete!"
  end

  desc "Build Docker image for production"
  task :build_prod do
    puts "Building production Docker image..."
    system("docker-compose -f docker-compose.prod.yml build") || abort("Build failed!")
    puts "Production build complete!"
  end

  desc "Build Docker image for Raspberry Pi (production)"
  task :build_raspberry_pi do
    puts "Building production Docker image for Raspberry Pi..."
    puts "This will build an ARM-compatible image..."
    system("docker-compose -f docker-compose.prod.yml build") || abort("Build failed!")
    puts "Raspberry Pi build complete!"
    puts "Start with: docker-compose -f docker-compose.prod.yml up -d"
  end

  desc "Start development environment"
  task :start_dev do
    puts "Starting development environment..."
    system("docker-compose up -d") || abort("Start failed!")
    puts "Development environment started!"
    puts "Run 'rake docker:setup_db' to set up the database"
  end

  desc "Start production environment"
  task :start_prod do
    puts "Starting production environment..."
    system("docker-compose -f docker-compose.prod.yml up -d") || abort("Start failed!")
    puts "Production environment started!"
    puts "Run 'rake docker:setup_db_prod' to set up the database"
  end

  desc "Stop development environment"
  task :stop_dev do
    puts "Stopping development environment..."
    system("docker-compose down")
    puts "Development environment stopped!"
  end

  desc "Stop production environment"
  task :stop_prod do
    puts "Stopping production environment..."
    system("docker-compose -f docker-compose.prod.yml down")
    puts "Production environment stopped!"
  end

  desc "Set up development database"
  task :setup_db do
    puts "Setting up development database..."
    system("docker-compose exec web bin/rails db:create") || abort("Database creation failed!")
    system("docker-compose exec web bin/rails db:migrate") || abort("Migration failed!")
    puts "Development database set up!"
  end

  desc "Set up production database"
  task :setup_db_prod do
    puts "Setting up production database..."
    system("docker-compose -f docker-compose.prod.yml exec web bin/rails db:create") || abort("Database creation failed!")
    system("docker-compose -f docker-compose.prod.yml exec web bin/rails db:migrate") || abort("Migration failed!")
    puts "Production database set up!"
  end

  desc "View development logs"
  task :logs_dev do
    exec("docker-compose logs -f")
  end

  desc "View production logs"
  task :logs_prod do
    exec("docker-compose -f docker-compose.prod.yml logs -f")
  end

  desc "Open Rails console in development"
  task :console_dev do
    exec("docker-compose exec web bin/rails console")
  end

  desc "Open Rails console in production"
  task :console_prod do
    exec("docker-compose -f docker-compose.prod.yml exec web bin/rails console")
  end
end

