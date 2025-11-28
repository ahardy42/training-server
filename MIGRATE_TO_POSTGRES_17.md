# Migrating to PostgreSQL 17 for PostGIS Support

This guide will help you migrate from PostgreSQL 14 to PostgreSQL 17 to enable PostGIS support.

## Steps

1. **Stop PostgreSQL 14**
   ```bash
   brew services stop postgresql@14
   ```

2. **Start PostgreSQL 17**
   ```bash
   brew services start postgresql@17
   ```

3. **Create new databases on PostgreSQL 17**
   ```bash
   createdb training_server_development
   createdb training_server_test
   ```

4. **Dump data from PostgreSQL 14** (if you have existing data)
   ```bash
   # Stop PostgreSQL 17 temporarily
   brew services stop postgresql@17
   
   # Start PostgreSQL 14
   brew services start postgresql@14
   
   # Dump the databases
   pg_dump training_server_development > training_server_development.dump
   pg_dump training_server_test > training_server_test.dump
   
   # Stop PostgreSQL 14
   brew services stop postgresql@14
   
   # Start PostgreSQL 17
   brew services start postgresql@17
   ```

5. **Restore data to PostgreSQL 17** (if you dumped data)
   ```bash
   psql training_server_development < training_server_development.dump
   psql training_server_test < training_server_test.dump
   ```

6. **Run migrations** (this will set up PostGIS)
   ```bash
   bundle exec rails db:migrate
   ```

7. **Update your PATH** (if needed) to use PostgreSQL 17's psql
   ```bash
   # Add to your ~/.zshrc or ~/.bash_profile:
   export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"
   ```

## Alternative: Fresh Start (if you don't need existing data)

If you don't have important data, you can simply:

```bash
# Stop PostgreSQL 14
brew services stop postgresql@14

# Start PostgreSQL 17
brew services start postgresql@17

# Drop and recreate databases
bundle exec rails db:drop
bundle exec rails db:create
bundle exec rails db:migrate
```

