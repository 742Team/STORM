FROM ruby:3.2

WORKDIR /app

# Install system dependencies for sqlite3 and ImageMagick
RUN apt-get update && apt-get install -y sqlite3 libsqlite3-dev imagemagick libmagickwand-dev

# Install bundler first
RUN gem install bundler

# Create Gemfile directly in the container
RUN echo "source 'https://rubygems.org'" > /app/Gemfile && \
    echo "gem 'sqlite3', '~> 1.6.0'" >> /app/Gemfile && \
    echo "gem 'sinatra', '~> 3.0'" >> /app/Gemfile && \
    echo "gem 'bcrypt'" >> /app/Gemfile && \
    echo "gem 'colorize'" >> /app/Gemfile && \
    echo "gem 'websocket-driver'" >> /app/Gemfile && \
    echo "gem 'webrick'" >> /app/Gemfile && \
    echo "gem 'rack'" >> /app/Gemfile && \
    echo "gem 'mini_magick'" >> /app/Gemfile

# Install gems
RUN bundle install

# Copy the application
COPY . /app/

# Expose only WebSocket port
EXPOSE 3630

# Start only the WebSocket server
CMD ["ruby", "srv_message.rb"]
