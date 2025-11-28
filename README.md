# Training Server

A Rails application for tracking and visualizing fitness activities with GPS data. Upload GPX and FIT files from your fitness devices, view detailed activity information, and explore your training data on interactive maps with heatmap visualizations.

## Features

- **Activity Management**: Upload and manage fitness activities from GPX and FIT files
- **Bulk Upload**: Import multiple activities at once via ZIP files
- **Interactive Maps**: 
  - Activity route visualization with start/end markers
  - Heatmap visualization showing all activity locations over time
  - Dynamic filtering by date range and activity type
  - Zoom-based detail loading for optimal performance
- **Activity Details**: View distance, duration, elevation, power, heart rate, and more
- **User Authentication**: Secure user accounts with Devise

## Prerequisites

Before you begin, ensure you have the following installed:

- **Ruby** (see `.ruby-version` for the required version)
- **PostgreSQL** 9.3 or higher
- **PostGIS** extension for PostgreSQL (required for spatial queries)
- **Node.js** (for JavaScript dependencies)
- **Bundler** gem

### Installing Prerequisites

#### macOS

```bash
# Install Homebrew if you haven't already
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Ruby (using rbenv or rvm)
brew install rbenv
rbenv install $(cat .ruby-version)
rbenv local $(cat .ruby-version)

# Install PostgreSQL
brew install postgresql@15
brew services start postgresql@15

# Install PostGIS
brew install postgis

# Install Node.js
brew install node
```

#### Ubuntu/Debian

```bash
# Install Ruby dependencies
sudo apt-get update
sudo apt-get install -y build-essential libssl-dev libreadline-dev zlib1g-dev

# Install rbenv (or use rvm)
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash

# Install PostgreSQL
sudo apt-get install -y postgresql postgresql-contrib

# Install PostGIS
sudo apt-get install -y postgresql-postgis

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

#### Windows

1. Install Ruby using [RubyInstaller](https://rubyinstaller.org/)
2. Install PostgreSQL from [postgresql.org](https://www.postgresql.org/download/windows/)
3. Install PostGIS from [PostGIS Windows Installer](https://postgis.net/windows_downloads/)
4. Install Node.js from [nodejs.org](https://nodejs.org/)

## Installation

1. **Clone the repository**

```bash
git clone <repository-url>
cd training-server
```

2. **Install Ruby dependencies**

```bash
bundle install
```

3. **Set up the database**

First, ensure PostgreSQL is running and create a database user (if needed):

```bash
# macOS/Linux
createuser -s your_username

# Or using psql
psql postgres
CREATE USER your_username WITH SUPERUSER;
\q
```

Then, configure your database connection in `config/database.yml` if needed (defaults usually work for local development).

4. **Run database setup**

```bash
# This will create the database, run migrations, and set up PostGIS
bin/rails db:create
bin/rails db:migrate
```

**Important**: The migrations will enable the PostGIS extension. If you encounter an error about PostGIS not being available, ensure PostGIS is installed and your PostgreSQL user has the necessary permissions.

5. **Set up the development environment**

```bash
bin/setup
```

This script will:
- Install dependencies
- Prepare the database
- Clear old logs and temp files
- Start the development server

Or run steps manually:

```bash
bin/rails db:prepare
bin/rails log:clear tmp:clear
```

## Running the Application

### Development Server

```bash
bin/dev
```

This starts the Rails server and asset pipeline. The application will be available at `http://localhost:3000`.

### Manual Start

```bash
# Start Rails server
bin/rails server

# In another terminal, start the asset pipeline (if needed)
bin/rails tailwindcss:watch
```

## Database Setup Details

### PostGIS Extension

This application uses PostGIS for efficient spatial queries on GPS trackpoints. The migration `20251128020000_add_postgis_support.rb` will:

- Enable the PostGIS extension
- Add a `location` geometry column to the `trackpoints` table
- Create a GIST spatial index for fast bounding box queries
- Set up a trigger to automatically update geometry when coordinates change

If you need to verify PostGIS is working:

```bash
psql training_server_development
CREATE EXTENSION IF NOT EXISTS postgis;
SELECT PostGIS_version();
\q
```

### Database Migrations

Run migrations to set up the database schema:

```bash
bin/rails db:migrate
```

To reset the database (⚠️ **WARNING**: This will delete all data):

```bash
bin/rails db:reset
```

## Usage

### Creating an Account

1. Navigate to `http://localhost:3000`
2. Click "Sign up" to create a new account
3. Log in with your credentials

### Uploading Activities

1. Go to the Activities page
2. Click "New Activity"
3. Choose one of:
   - **Single File Upload**: Upload a GPX or FIT file
   - **Bulk Upload**: Upload a ZIP file containing multiple GPX/FIT files
   - **Manual Entry**: Manually enter activity details

### Viewing Activities

- **List View**: See all your activities on the Activities page
- **Detail View**: Click an activity to see detailed information including:
  - Activity metrics (distance, duration, elevation, etc.)
  - Interactive route map showing the GPS track
  - Start and end markers on the map

### Heatmap Visualization

1. Navigate to the Map page
2. Select a date range (defaults to your first to last activity)
3. Optionally filter by activity type
4. The heatmap will show all your activity locations
5. Zoom and pan to see more detail - the map automatically loads points for the visible area

## Development

### Running Tests

```bash
bin/rails test
```

### Code Quality

```bash
# Lint Ruby code
bin/rubocop

# Security scan
bin/brakeman
```

### Database Console

```bash
bin/rails dbconsole
```

### Rails Console

```bash
bin/rails console
```

## Project Structure

```
app/
  controllers/     # Application controllers
  models/          # ActiveRecord models (Activity, Track, Trackpoint, User)
  services/        # Business logic (ActivityFileParser)
  views/           # ERB templates
  javascript/      # Stimulus controllers for interactive features
  assets/          # Stylesheets and images

db/
  migrate/         # Database migrations
  schema.rb        # Current database schema

config/
  routes.rb        # Application routes
  database.yml     # Database configuration
```

## Key Technologies

- **Rails 8.0**: Web framework
- **PostgreSQL**: Database
- **PostGIS**: Spatial database extension
- **Devise**: Authentication
- **Tailwind CSS**: Styling
- **Stimulus**: JavaScript framework
- **Leaflet**: Interactive maps
- **Leaflet.heat**: Heatmap visualization

## Troubleshooting

### PostGIS Extension Error

If you see an error about PostGIS not being available:

1. Verify PostGIS is installed:
   ```bash
   # macOS
   brew list postgis
   
   # Ubuntu/Debian
   dpkg -l | grep postgis
   ```

2. Check PostgreSQL can access PostGIS:
   ```bash
   psql training_server_development
   CREATE EXTENSION postgis;
   SELECT PostGIS_version();
   ```

3. Ensure your database user has permission to create extensions

### Database Connection Issues

- Verify PostgreSQL is running: `brew services list` (macOS) or `sudo systemctl status postgresql` (Linux)
- Check `config/database.yml` for correct database name and credentials
- Ensure the database exists: `bin/rails db:create`

### Asset Pipeline Issues

- Clear the asset cache: `bin/rails tmp:clear`
- Rebuild assets: `bin/rails assets:precompile` (production) or restart `bin/dev`

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[Add your license here]

## Support

For issues and questions, please open an issue on GitHub.
