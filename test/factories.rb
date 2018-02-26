FactoryGirl.define do
  sequence(:email) {|n| "gojiuser-#{n}@emmoco.com" }
  sequence(:count)

  factory :account do  
    first_name            "Test"
    last_name             "Account"
    email                 "glenn.widener@room5.com"
    password              "password"
    password_confirmation "password"
    trait(:admin)  { admin  true }
  end

  factory :device do 
    user
    sequence(:name) {|n| "device-#{n}" }
    sequence(:ua_token) {|n| "#{n}" }
  end

  factory :user do
    account
  end

  factory :key do
    sequence(:name) {|n| "#{n} Key" }
  end

  factory :lock  do
    sequence(:name) {|n| "#{n} Lock" }
  end

  #incomplete below here???
  factory :event do
    key
    event_time Time.now
    event_type { ["locked", "unlocked", "denied" ]} 
  end

  factory :notification do
    key
    access_time
    access { ["locked", "unlocked", "denied" ]} 
  end

  factory :time_constraint do
    key
    access_time
    access { ["locked", "unlocked", "denied" ]} 
  end
end
