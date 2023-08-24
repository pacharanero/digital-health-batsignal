FROM ruby:3.2.2-bullseye

RUN mkdir /app
WORKDIR /app

# copy Gemfile and Gemfile.lock and run bundle install
COPY Gemfile /app/
COPY Gemfile.lock /app/
RUN bundle install --binstubs

# copy the app code into the container
COPY . /app

CMD ["ruby", "batsignal.rb", "-o", "0.0.0.0"]

