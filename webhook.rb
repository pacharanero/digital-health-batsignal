require 'sinatra'
require 'httparty'
require 'json'

# logging
require 'logger'
require 'colorize'

# discourse
require 'discourse_api'

# twilio
require 'twilio-ruby'

# gdocs
# require 'google/apis/drive_v2'
# require 'google/api_client/client_secrets'
# require 'oauth2'

# security
require 'dotenv/load'
require 'sanitize'

log = Logger.new(STDOUT)

get '/' do
  "webhook responder"
end

# def client
#   client ||= OAuth2::Client.new(GOOGLE_API_CLIENT_ID, GOOGLE_API_SECRET, {
#                 :site => 'https://accounts.google.com',
#                 :authorize_url => "/o/oauth2/auth",
#                 :token_url => "/o/oauth2/token"
#               })
# end

# # endpoint for authorizing Google Docs API
# get "/auth" do
#   redirect client.auth_code.authorize_url(:redirect_uri => redirect_uri,:scope => SCOPES,:access_type => "offline")
# end
#
# get "/auth_success" do
#   "successfully authenticated to Google API"
# end

# catch the webhook from a new topic
post '/webhook' do
  body = JSON.parse(request.body.read)
  # log webhook payload
  log.debug("webhook body: #{body}\n".green) if request.body
  log.debug("webhook custom headers: #{request.env}\n".green) if request.env
  log.debug("webhook standard headers: #{headers}\n".green) if headers

  # check_secret_token
  secret = ENV['WEBHOOK_SECRET']

  # check that the source matches what we are expecting
  if ENV["DISCOURSE_URL"] == request.env["HTTP_X_DISCOURSE_INSTANCE"]
    discourse = DiscourseApi::Client.new(ENV['DISCOURSE_URL'])
    discourse.api_key = ENV["DISCOURSE_API_KEY"]
    discourse.api_username = ENV["DISCOURSE_USERNAME"]

    # get further detail on the topic
    topic_id = body['topic']['id']
    if topic_id.class == Integer
      topic = discourse.topic(topic_id)
      log.debug("topic id: #{topic_id}\n".green)
      log.debug("topic: #{topic}\n".green)
    else
      log.error("topic was not found by id #{topic_id}\n".red)
      error 500
    end

    # collect information for the SMS
    topic_title = topic['title']
    log.debug("topic title: #{topic_title}".green)
    first_post_cooked = topic['post_stream']['posts'].first['cooked']
    log.debug("first post 'cooked' text: #{first_post_cooked}".green)
    first_post_sanitized = Sanitize.clean(first_post_cooked)
    log.debug("first post sanitized text: #{first_post_sanitized}".green)
    topic_url = ENV["DISCOURSE_URL"] + "/t/" + topic_id.to_s
    log.debug("first post url: #{topic_url}\n".green)

    # close the topic immediately (discourse API)
    # status = "closed"

  else
    log.error("webhook URL did not match ENV-configured expected URL\n".red)
    error 401
  end

  # format SMS text
  sms_text = <<~SMS
  TITLE: #{topic_title}
  SHORT ALERT: #{first_post_sanitized.strip!}
  MORE INFO: #{topic_url}
  [to unsubscribe: email #{ENV['ADMIN_USER_CONTACT']}]
  SMS
  log.debug("formatted SMS text block: \n #{sms_text}")
  log.debug("(formatted SMS text character count: #{sms_text.length})\n")

  # get list of SMS numbers
  numbers_list = ['+447747600617', '+447790497135']

  # send SMS messages
  client = Twilio::REST::Client.new(
    ENV['TWILIO_ACCOUNT_SID'],
    ENV['TWILIO_AUTH_TOKEN']
  )
  log.debug("twilio client created #{client}")

  numbers_list.each do |number|
    if number # need to add test for validity
      # reject invalid UK mobile numbers (ie non +447)
      msg = client.messages.create(
        from: ENV['TWILIO_NUMBER'],
        to: number,
        body: sms_text
      )
      log.debug("twilio message sent: #{msg}")
    else
      log.error("invalid UK mobile number #{number}")
    end
  end

  # report errors to admin
  # report invalid numbers to admin
  # report completion to admin

end

# schedule weekly tests automatically
# end-to-end integration test
