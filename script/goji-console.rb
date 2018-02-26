#!/usr/bin/env ruby

require 'rubygems'
require 'debugger'
require 'httparty'
require 'json'
require 'ap'
require 'ruby-debug'
require 'ripl'
require 'ripl/multi_line'
require 'awesome_print'

class GojiServer
  include HTTParty
  format :json
  
  @@token = 'bad token'

  @@base_url = 'http://localhost:3000' #'http://goji-server-staging.herokuapp.com'

  def self.url(url)
    @@base_url = 'http://' + url
  end

  def self.auth(email='goji1@emmoco.com', password='aba456')
    @response = GojiServer.get(@@base_url + "/authtoken", :body => {"email" => email, "password" => password})
    @@token = @response["authtoken"]
    ap @response.response.code
    ap @response.headers
    return JSON.parse(@response.body)
  end

  def self.locks
    @response = GojiServer.get(@@base_url + "/locks", :body => {'authtoken' => @@token})
    ap @response.response.code
    ap @response.headers
    return JSON.parse(@response.body)
  end

  def self.keys
    @response = GojiServer.get(@@base_url + "/keys", :body => {'authtoken' => @@token})
    ap @response.response.code
    ap @response.headers
    return JSON.parse(@response.body)
  end

  def self.notifications
    @response = GojiServer.get(@@base_url + "/notifications", :body => {'authtoken' => @@token})
    ap @response.response.code
    ap @response.headers
    return JSON.parse(@response.body)
  end

  def self.make_event(key_id, event_time, event_type, string_value)
    @response = GojiServer.post(@@base_url + "/events", :body => {
                                  'authtoken'   => @@token, 
                                  'event_time'  => event_time,
                                  'event_type'  => event_type,
                                  'string_value'=> string_value,
                                  'key_id'      => key_id }) 
    ap @response.response.code
    ap @response.headers
    return JSON.parse(@response.body)
  end

  def self.mark_read(notification_id)
    @response = GojiServer.put(@@base_url + "/notifications/#{notification_id}", 
                               :body => {'authtoken'   => @@token, 
                               'notification_id'      => notification_id }) 
    ap @response.response.code
    ap @response.headers
  end

  def self.create_key(lock_id, email)
    @response = GojiServer.post(@@base_url + "/keys", :body => {'authtoken'   => @@token, 
                                                                        'email'      => email,
                                                                        'lock_id'      => lock_id })
    ap @response.response.code
    ap @response.headers
  end

  def self.token(token=nil)
    @@token = token if token
    puts @@token
  end

end

def url(*args)
  GojiServer.url(*args)
end

def auth(*args)
  GojiServer.auth(*args)
end

def locks(*args)
  @locks = GojiServer.locks(*args)
end

def keys(*args)
  @keys = GojiServer.keys(*args)
end

def notifications(*args)
  @notifications = GojiServer.notifications(*args)
end

def make_event(*args)
  GojiServer.make_event(*args)
end

def mark_read(*args)
  GojiServer.mark_read(*args)
end

def token(*args)
  GojiServer.token(*args) 
end

def create_key(*args)
  GojiServer.create_key(*args)
end

def lock_keys
  locks
  @locks.each do |l|
    print "lock : #{l["id"]}\n"
    l["keys"].each do |k|
      print "\t#{k["name"]}\n"
    end
  end
  return nil
end

def staging
  url "goji-server-staging.herokuapp.com"
end

def production
  url "goji-server.herokuapp.com"
end


def all
  auth
  puts locks
  puts keys
  puts notifications
  puts "locks :#{@locks.size}\nkeys: #{@keys.size}\nnotifications: #{@notifications.size}\n"
end

def help
  print "***** Commands \n"
  print "url 'url'                       # set the url, no http required, default is staging\n"
  print "auth 'email', 'password'        # get the auth token, default is goji1@emmoco.com\n"
  print "keys                            # get the list of keys for this user\n"
  print "locks                           # get the list of locks for this user\n"
end

Ripl.start

