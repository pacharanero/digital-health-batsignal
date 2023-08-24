# discourse-batsignal

Discourse Batsignal (webhook) SMS responder

### Installation in a new environment using `rbenv`

Install ruby using rbenv
```bash
curl -fsSL <https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer> | bash
```

Add rbenv to your path
```bash
echo 'eval "$(/home/batsignal/.rbenv/bin/rbenv init - bash)"' >> ~/.bashrc
```

Install build dependencies
```bash
apt-get install autoconf patch build-essential rustc libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libgmp-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev libdb-dev uuid-dev
```

Install a Ruby version (currently 3.2.2)
```bash
rbenv install 3.2.2
```

Set this Ruby to the be the default
```bash
rbenv global 3.2.2
```

### Running locally

- use [ngrok](https://ngrok.com/) to securely tunnel your local server out to the web in order to receive webhooks
  `ruby batsignal.rb` # Sinatra runs on port 4567 by default
  `ngrok -http 4567` # expose this port via ngrok

### Running on Heroku for production

- use `heroku config:push` to sync local configs up to heroku instance
- use `heroku logs -t` to tail the heroku remote logs in local terminal

### How does the Batsignal work?

#### 1) Google Form as a simple signup arrangement

- Mobile Numbers and other data are entered into a Google Form
- Processing: Regex is performed to ensure that the number starts with '7', onits the initial '0' and is 10 digits long
- Entries in the form become a new row in the Google Sheet
- Privacy policy is explained

#### 2) Google Sheet used as a simple easily-editable private database

- Numbers are maintained in a list allowing simple editing, removal etc
- Numbers are **de-duplicated** and **concatenated** into a single comma-separated string so they can be looked up using the Google Sheets API

#### 3) Discourse trigger

- Up to this point, nothing happens until a new topic is made in the Category 'Batsignal' in Discourse.
- Once a topic is created, Discourse sends a webhook to the Batsignal responder, which runs on Heroku.

#### 4) Batsignal Webhook responder

- In response to a new post in the Batsignal area of the Digital Health Networks, the responder receives data in the webhook content from Discourse
- The responder gets a list of Batsignal numbers from Google Sheets
- It builds an SMS payload and sends it to each recipient via Twilio
- It also sends an admin email to indicate success, and reports any invalid numbers

#### 5) Batsignal Weekly Testing

### Steps to testing a new version into Live

#### 1. Testing locally using the test-webhook-locally.rb file

- Running the file with `ruby test-webhook-locally.rb` sends a dummy topic payload to localhost:4567 to be picked up by Sinatra.
- Some parts will not work, such as Sinatra's use of the Discourse API to auto-close the topic
- But it can help debugging and testing rapidly or without internet access
- the `test` variable is set

#### 2. Testing locally using the Test webhook to an Ngrok URL

- Ngrok Webhook config: https://discourse.digitalhealth.net/admin/api/web_hooks/4
- Posts in the `batsignal-dev-test` category trigger test webhooks sent to the Ngrok URL, which are sent to your locally running code
- Discourse API events will still work and will take effect on the `batsignal-dev-test` category
- SMS events will still work.

#### 3. Testing code pushed to Heroku using a different webhook

- Switch off the Ngrok webhook first, and enable the Heroku webhook.
- Heroku Webhook config: https://discourse.digitalhealth.net/admin/api/web_hooks/9
- Posts in the `batsignal-dev-test` category trigger test webhooks sent to the live service
- IMPORTANT!!!! - push any updates to the ENV using `heroku config:push` BUT manually edit the environment variables in Heroku so that it uses the TEST-LOOKUP tab in the source spreadsheet (otherwise you will send test SMSs to 500+ people)
- Discourse API events will still work and will take effect on the `batsignal-dev-test` category
- SMS events will still work.

#### 4. Live

- Switch the Live webhook back on https://discourse.digitalhealth.net/admin/api/web_hooks/7
- Switch off all other webhooks
- Edit the Heroku ENV vars so that `SHEET_TAB_NAME='LIVE-LOOKUP'` and `DEPLOY_STATUS=live`
- Test with a post in `batsignal` (BATSIGNAL - EMERGENCY SMS ALERTING) which will be notified to the entire Batsignal database of users.
