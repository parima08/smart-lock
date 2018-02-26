require "test_helper"

class ApplicationControllerTest < ActionController::TestCase
  describe ApplicationController do

    subject { ApplicationController }

    before do
      DatabaseCleaner.start
      @user = make_user
      @json = JSON.parse(response.body)
    end

    after do 
      DatabaseCleaner.clean
    end


  end

end
