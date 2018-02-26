class HomeController < ApplicationController

  force_ssl if: lambda {GojiServer.config.use_ssl_if_possible}

  before_action :authenticate_account!

  def index
    # placeholder route
  end

end
