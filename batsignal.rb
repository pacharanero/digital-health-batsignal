require 'sinatra'
require 'httparty'
require 'json'
require 'stringio'

# logging
require 'logger'
require 'colorize'

# emails
require 'mailgun-ruby'

require 'discourse_api'
require 'twilio-ruby'

# gdocs
require 'google_drive'

# security
require 'dotenv'
require 'sanitize'

# debugging
require 'pry'

# setup
log = Logger.new(STDOUT)

if ENV['DEPLOY_STATUS'] == 'live'
  Dotenv.load('config/live.env')
  log.debug("Loaded LIVE environment")
else
  Dotenv.load('config/test.env')
  log.debug("Loaded TEST environment")
end

admin_email_content=""

drive = GoogleDrive::Session.from_service_account_key(
  StringIO.new( ENV['GOOGLE_SERVICE_SECRET'] )
)

mailer = Mailgun::Client.new ENV['MAILGUN_API_KEY'], ENV['MAILGUN_API_ENDPOINT']

# for testing only
get '/' do
  "Discourse Batsignal GET"
end

post '/' do
  "Discourse Batsignal POST"
end

# catch the webhook from a new topic
post '/batsignal' do
  # parse the JSON request body
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

    # set up Discourse API
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
      log.debug("Topic #{topic['id']} has been closed - no SMS is sent on the actual closure event\n".green)
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

    # close the topic immediately (Discourse API)
    discourse.change_topic_status(
      topic['slug'],
      topic['id'],
      {:status => 'closed', :enabled => 'true', :api_username => ENV['DISCOURSE_USERNAME'] })

  else
    log.error("webhook URL #{ENV["DISCOURSE_URL"]} did not match ENV-configured expected URL #{request.env["HTTP_X_DISCOURSE_INSTANCE"]}\n".red)
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
    numbers_list = spreadsheet.worksheet_by_title(ENV['SHEET_TAB_NAME'])[2,2].split(",")
  rescue
    log.error("spreadsheet or worksheet was not found by id".red)
    error 500
  end

  # send SMS messages
  client = setup_sms(log)
  invalid_numbers = send_sms(client, numbers_list, sms_text, log, admin_email_content)

  # report errors to admin

  # report invalid numbers to admin
  # report completion to admin
  admin_email_content += "Successful Batsignal Sent\n"
  admin_email_content += "#{numbers_list.length} numbers messaged\n"
  admin_email_content += "#{invalid_numbers.length} invalid numbers\n"
  if invalid_numbers.length > 0
    admin_email_content += "ACTION: remove invalid numbers #{invalid_numbers}"
  end
  email_admins(mailer, admin_email_content, log)

end

# TODO: end-to-end integration test

def setup_sms(log)
  client = Twilio::REST::Client.new(
    ENV['TWILIO_ACCOUNT_SID'],
    ENV['TWILIO_AUTH_TOKEN']
  )
  log.debug("twilio client created #{client}".green)
  return client
end

def send_sms(client, numbers_list, sms_text, log, admin_email_content)
  invalid_numbers = []
  numbers_list.each do |number|
    if number.slice(0,3) == "447"
      msg = client.messages.create(
        from: ENV['TWILIO_NUMBER'],
        to: number,
        body: sms_text
      )
      log.debug("Twilio message sent to #{number.slice(-6,6)} Excerpt: #{sms_text.split(//).last(50).join}".green)
    else
      invalid_numbers << number
      log.error("Invalid UK mobile number #{number}".red)
    end
  end
  return invalid_numbers
end

def email_admins(mailer, admin_email_content, log)
  # collect content
  message_params =  { from: 'batsignal@digitalhealth.net',
                      to: ENV['ADMIN_USER_CONTACT'],
                      subject: 'Batsignal Admin Report',
                      text: admin_email_content }
  # send mail
  response = mailer.send_message 'mg.discourse.digitalhealth.net', message_params
  log.debug("mailer response #{response.inspect}".green)
end
