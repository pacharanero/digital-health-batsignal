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
require 'google_drive'

# security
require 'dotenv/load'
require 'sanitize'

# debugging
require 'pry'

log = Logger.new(STDOUT)
drive = GoogleDrive::Session.from_service_account_key(
  StringIO.new( ENV['GOOGLE_SERVICE_SECRET'] )
)

get '/' do
  "webhook responder"
end



# catch the webhook from a new topic
post '/webhook' do
  body = JSON.parse(request.body.read)
  # log webhook payload
  log.debug("webhook body: #{body}\n".green) if request.body
  log.debug("webhook custom headers: #{request.env}\n".green) if request.env
  log.debug("webhook standard headers: #{headers}\n".green) if headers

  # check_secret_token
  # secret = ENV['WEBHOOK_SECRET']
  # https://developer.github.com/webhooks/securing/

  # check that the webhook origin matches the domain we are expecting
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

    # don't send SMS on topic deletion events
    if topic['deleted_at']
      log.debug("Topic #{topic['id']} is being deleted - no SMS sent on deletion events\n".green)
      return
    end

    # don't send SMS for closed topics
    # avoids dual notifications because Discourse sends a webhook
    # for topic creation AND closure events
    if topic['closed'] == true
      log.debug("Topic #{topic['id']} is closed - no SMS sent on closure events\n".green)
      return
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

    # TODO: truncate the SHORT ALERT body text

    # close the topic immediately (discourse API)
    discourse.change_topic_status(
      topic['slug'],
      topic['id'],
      {:status => 'closed', :enabled => 'true'})

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

  # get list of SMS numbers securely from Google Sheet where they are managed
  begin
    spreadsheet = drive.spreadsheet_by_title('Batsignal Numbers List')
    numbers_list = spreadsheet.worksheet_by_title('TEST-LOOKUP')[2,2].split(",")
  rescue
    log.error("spreadsheet or worksheet was not found by id".red)
    error 500
  end

  # send SMS messages
  client = setup_sms(log)
  send_sms(client, numbers_list, sms_text, log)

  # send to mattermost for Pharmoutcomes
  # mattermost_sender(sms_text, log)

  # report errors to admin
  # report invalid numbers to admin
  # report completion to admin

end

# schedule weekly tests automatically
# end-to-end integration test

def mattermost_sender(text,  log)
  require 'uri'
  require 'net/http'
  url = URI("https://chat.pharmoutcomes.org/hooks/wrxu4jimoinnpmir6k8m4y14hc")
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Post.new(url)
  request["content-type"] = 'application/json'
  request.body = "{
    \"text\": \"#{text}\"
    \"channel\": \"news-security\",
    \"username\": \"dhi-batsignal\",
    \"icon_url\": \"\",
  }"
  response = http.request(request)
  puts response
end

def setup_sms(log)
  client = Twilio::REST::Client.new(
    ENV['TWILIO_ACCOUNT_SID'],
    ENV['TWILIO_AUTH_TOKEN']
  )
  log.debug("twilio client created #{client}")
  return client
end

def send_sms(client, numbers_list, sms_text, log)
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
end
