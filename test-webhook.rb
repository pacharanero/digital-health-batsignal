require 'httparty'
require 'json'

# TODO convert this into a proper test case

headers = {
  "Content-Type" => 'application/json'
}
body = {
  :post => {
    :id => 22644,
    :name => "Marcus Baw",
    :username => "pacharanero",
    :avatar_template => "/user_avatar/discourse.digitalhealth.net/pacharanero/{size}/2066_1.png",
    :created_at => "2018-06-04T08:11:40.805Z",
    :cooked => "<p>This topic was automatically closed after 15 minutes. New replies are no longer allowed.</p>",
    :post_number => 2,
    :post_type => 3,
    :updated_at => "2018-06-04T08:11:40.805Z",
    :reply_count => 0,
    :reply_to_post_number => 'null',
    :quote_count => 0,
    :avg_time => 'null',
    :incoming_link_count => 0,
    :reads => 0,
    :score => 0,
    :topic_id => 6047,
    :topic_slug => "monday-morning-batsignal-test-04-06-2018",
    :topic_title => "Monday Morning Batsignal Test 04.06.2018",
    :display_username => "Marcus Baw",
    :primary_group_name => "CCIO_LN_AdvisoryBrd",
    :version => 1,
    :user_title => "Discourse Wrangler & CCIO Network - Advisory Board Member",
    :moderator => true,
    :admin => true,
    :staff => true,
    :user_id => 1,
    :hidden => false,
    :trust_level => 4,
    :deleted_at => 'null',
    :user_deleted => false,
    :edit_reason => 'null',
    :wiki => false,
    :action_code => "autoclosed.enabled",
    :topic_posts_count => 2
  }
}
resp = HTTParty.post(
  'http://localhost:4567/webhook',
  :headers => headers,
  :body => body)
puts resp
