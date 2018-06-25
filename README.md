# discourse-webhook-sinatra
Discourse Webhook responder in Sinatra

### Running locally
* use [ngrok](https://ngrok.com/) to securely tunnel your local server out to the web in order to receive webhooks

### Runnig on Heroku for production
* use `heroku config:push` to sync local configs up to heroku instance
* use `heroku logs -t` to tail the heroku remote logs in local terminal
