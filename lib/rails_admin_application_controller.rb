require "rails_admin/application_controller"

module RailsAdmin
  class ApplicationController < ::ApplicationController
    before_filter :save_uuid, :only => [:create, :new]
   
   private

    def save_uuid
      if !params[:model_name].empty? && params[params[:model_name]]
        params[params[:model_name]][:uuid] = request.uuid
      end
    end
  end
end