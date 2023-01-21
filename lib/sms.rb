module Batsignal

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
        log.debug("twilio message sent: #{msg}".green)
      else
        invalid_numbers << number
        log.error("invalid UK mobile number #{number}".red)
      end
    end
    return invalid_numbers
  end

end