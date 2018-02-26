module RailsAdmin
  module Config
    module Actions
      class ViewLogs < RailsAdmin::Config::Actions::Base
        register_instance_option :member? do
          true
        end
        register_instance_option :link_icon do
         'icon-eye-open'
        end

        register_instance_option :controller do
          Proc.new do
            controller = params[:model_name].camelize.constantize
            object = controller.find(params[:id])
            puts object.to_json
            if object.uuid 
              request = HTTParty.get("https://papertrailapp.com/api/v1/events/search.json?system_id=#{ENV['PAPERTRAIL_SYSTEM_ID']}&q=#{object.uuid}", 
                              :headers => { "X-Papertrail-Token" => ENV['PAPERTRAIL_AUTH_TOKEN']})
              if request["events"] && !request["events"].empty? 
                @msg = request["events"]
              else
                @err = "There are no events for uuid: #{object.uuid}"
              end
            else
              @err = "This #{params[:model_name]} doesn't have a UUID"
            end
            respond_to do |format|
              format.html { render @action.template_name }
            end
          end
        end
        RailsAdmin::Config::Actions.register(self)

      end
    end
  end
end