#!/usr/bin/env ruby
# all config is in ENV vars
require 'discourse_api'
require 'date'
require 'dotenv'
require 'logger'
Dotenv.load('config/test.env')

@logger = Logger.new(STDOUT)

def send_batsignal
  # set up client
  client = DiscourseApi::Client.new(ENV['DISCOURSE_URL'])
  client.api_key, client.api_username = ENV['DISCOURSE_API_KEY'], ENV['DISCOURSE_API_USER']

  # create new topic on Discourse
  begin
    client.create_topic(
      category: ENV['DISCOURSE_CATEGORY'],
      skip_validations: true,
      auto_track: false,
      title: ENV['BATSIGNAL_TEST_TITLE'] + " " + DateTime.now.strftime("%Y.%m.%d"),
      raw: ENV['BATSIGNAL_TEST_TEXT']
    )
    @logger.info "BATSIGNAL TEST SENT - #{Date.today.strftime('%A')} #{DateTime.now.strftime("%Y.%m.%d")} CATEGORY: #{ENV['DISCOURSE_CATEGORY']}"
  rescue DiscourseApi::UnprocessableEntity => error
    # `body` is something like `{ errors: ["Name must be at least 3 characters"] }`
    # This outputs "Name must be at least 3 characters"
    # email errors to admin
    puts error.response.body['errors'].first
    @logger.error "Batsignal sending errored: #{error.response.body['errors'].first}"
  end
end

send_batsignal

# email notification to admin
