require 'httparty'
require 'json'

# sends a dummy webhook to the Batsignal application

headers_hash = { :"Content-Type" => "application/json",
                 :"X_DISCOURSE_INSTANCE" => "https://discourse.digitalhealth.net"
               }

body_hash = {
"topic"=>                                                       
  {"tags"=>[],                                                   
   "tags_descriptions"=>{},                                      
   "id"=>28281,                                                  
   "title"=>"Monday Morning Batsignal Test 2023.02.06",          
   "fancy_title"=>"Monday Morning Batsignal Test 2023.02.06",    
   "posts_count"=>2,                                             
   "created_at"=>"2023-02-06T09:00:24.096Z",                     
   "views"=>1,                                                   
   "reply_count"=>0,                                             
   "like_count"=>0,                                              
   "last_posted_at"=>"2023-02-06T09:00:25.483Z",                 
   "visible"=>true,                                   
   "closed"=>true,                                    
   "archived"=>false,
   "archetype"=>"regular",
   "slug"=>"monday-morning-batsignal-test-2023-02-06",
   "category_id"=>56,
   "word_count"=>5,
   "deleted_at"=>nil,
   "user_id"=>1,
   "featured_link"=>nil,
   "pinned_globally"=>false,
   "pinned_at"=>nil,
   "pinned_until"=>nil,
   "unpinned"=>nil,
   "pinned"=>false,
   "highest_post_number"=>2,
   "deleted_by"=>nil,
   "has_deleted"=>false,
   "bookmarked"=>false,
   "participant_count"=>1,
   "thumbnails"=>nil,
   "created_by"=>
    {"id"=>1,
     "username"=>"pacharanero",
     "name"=>"Marcus Baw",
     "avatar_template"=>"/user_avatar/discourse.digitalhealth.net/pacharanero/{size}/2066_2.png"},
   "last_poster"=>
    {"id"=>1,
     "username"=>"pacharanero",
     "name"=>"Marcus Baw",
     "avatar_template"=>"/user_avatar/discourse.digitalhealth.net/pacharanero/{size}/2066_2.png"}}}

puts headers_hash.to_json
puts body_hash.to_json

resp = HTTParty.post(
  'http://localhost:4567/batsignal',
  headers: headers_hash,
  body: body_hash.to_json)