#!/bin/bash

# Update package list
sudo apt-get update

# Install dependencies
sudo apt-get install build-essential curl git libpq-dev nodejs yarn

# Install Mastodon
git clone https://github.com/tootsuite/mastodon.git
cd mastodon

# Checkout the latest release
git checkout $(git tag -l | grep -v 'rc[0-9]*$' | sort -V | tail -n 1)

# Install Ruby and Bundler
sudo apt-get install ruby-full
sudo gem install bundler

# Install Mastodon's dependencies
bundle install --deployment --without development test

# Create a Mastodon user
sudo useradd -m mastodon

# Create a .env.production file
cp .env.production.sample .env.production

# Generate a secure secret key
bundle exec rake secret

# Set the secret key in the .env.production file
SECRET_KEY_BASE=your_secret_key_here

# Configure the database
DB_HOST=localhost
DB_USER=mastodon
DB_NAME=mastodon_production

# Create the database user and grant privileges
sudo -u postgres psql
# Inside the psql shell:
CREATE USER mastodon;
ALTER USER mastodon CREATEDB;
\q

# Create the database
bundle exec rake db:create

# Run database migrations
bundle exec rake db:migrate

# Compile CSS and JavaScript assets
yarn install
yarn run webpack

# Precompile Mastodon's localization files
bundle exec rake assets:precompile

# Set up a systemd service for Mastodon
sudo tee /etc/systemd/system/mastodon-web.service <<EOL
[Unit]
Description=mastodon-web
After=network.target

[Service]
Type=simple
User=mastodon
WorkingDirectory=/home/mastodon/mastodon
Environment="RAILS_ENV=production"
Environment="PORT=3000"
ExecStart=/usr/bin/bundle exec puma -C config/puma.rb
TimeoutSec=15
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Start the Mastodon service and enable it to start on boot
sudo systemctl start mastodon-web
sudo systemctl enable mastodon-web
