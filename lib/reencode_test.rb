require 'httparty'
file = File.open("#{Dir.pwd}/picture.jpeg", 'r')
puts "Loaded Picture : #{Dir.pwd}/picture.jpeg\n"
data = file.read
file.close

encoded_data = Base64.strict_encode64(data)

#puts encoded_data

response = HTTParty.post("http://goji-server-staging.herokuapp.com/events	
.json", {body: {
  authtoken: 'p93YA5TdyFvMsEVQqsKC', 
  key_id: 3,
  access_time:"2013-12-07T11:22:33.000Z",
  access: 'unlocked',
  picture: {original_filename: 'picture.jpeg',
            content_type:'image/jpeg',
            data: encoded_data}
}})

#puts "Request sent to goji-server.herokuapp.com (production)\n"
puts "Status: #{response.code}\n"
