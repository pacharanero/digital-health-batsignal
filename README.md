# discourse-webhook-sinatra
Discourse Webhook responder in Sinatra

### Running locally
* use [ngrok](https://ngrok.com/) to securely tunnel your local server out to the web in order to receive webhooks
`ruby webhook.rb` # Sinatra runs on port 4567 by default
`ngrok -http 4567` # expose this port via ngrok

### Running on Heroku for production
* use `heroku config:push` to sync local configs up to heroku instance
* use `heroku logs -t` to tail the heroku remote logs in local terminal

### How does the Batsignal work?

#### 1) Google Form as a simple signup arrangement
* Mobile Numbers and other data are entered into a Google Form
* Processing: Regex is performed to ensure that the number starts with '7', onits the initial '0' and is 10 digits long
* Entries in the form become a new row in the Google Sheet
* Privacy policy is explained
#### 2) Google Sheet used as a simple easily-editable private database
* Numbers are maintained in a list allowing simple editing, removal etc
* Numbers are **de-duplicated** and **concatenated** into a single comma-separated string so they can be looked up using the Google Sheets API
#### 3) Discourse trigger
* Up to this point, nothing happens until a new topic is made in the Category 'Batsignal' in Discourse.
* Once a topic is created, Discourse sends a webhook to the Batsignal responder, which runs on Heroku.
#### 4) Batsignal Webhook responder
* In response to a new post in the Batsignal area of the Digital Health Networks, the responder receives data in the webhook content from Discourse
* The responder gets a list of Batsignal numbers from Google Sheets
* It builds an SMS payload and sends it to each recipient via Twilio
* It also sends an admin email to indicate success, and reports any invalid numbers
#### 5) Batsignal Weekly Testing
