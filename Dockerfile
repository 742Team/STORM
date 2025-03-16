FROM ruby:3.2

WORKDIR /app

# Install system dependencies for sqlite3 and ffmpeg
RUN apt-get update && apt-get install -y sqlite3 libsqlite3-dev ffmpeg libtag1-dev

# Install bundler first
RUN gem install bundler

# Create Gemfile directly in the container
RUN echo "source 'https://rubygems.org'" > /app/Gemfile &&     echo "gem 'sqlite3', '~> 1.4.0'" >> /app/Gemfile &&     echo "gem 'sinatra', '~> 3.0'" >> /app/Gemfile &&     echo "gem 'bcrypt'" >> /app/Gemfile &&     echo "gem 'colorize'" >> /app/Gemfile &&     echo "gem 'websocket-driver'" >> /app/Gemfile &&     echo "gem 'webrick'" >> /app/Gemfile &&     echo "gem 'rack'" >> /app/Gemfile &&     echo "gem 'mini_magick'" >> /app/Gemfile &&     echo "gem 'taglib-ruby', '~> 1.1.0'" >> /app/Gemfile

# Install gems
RUN bundle install

# Copy the application
COPY . /app/

# Create upload directory with proper permissions
RUN mkdir -p /app/public/uploads
RUN chmod 755 /app/public/uploads

# Expose ports
EXPOSE 3630 4567

# Start both servers - updated to use the new app.rb file instead of lib/app_config.rb
CMD ["sh", "-c", "ruby srv_message.rb & ruby srv_upload.rb"]
