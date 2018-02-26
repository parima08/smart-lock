require 'rails_admin/config/actions'
require 'rails_admin/config/actions/base'

# Decommission a lock.
# This code adapted from the RailsAdmin delete.rb action.

module RailsAdmin
  module Config
    module Actions
      class Decommission < RailsAdmin::Config::Actions::Base

        register_instance_option :member do
          true
        end

        register_instance_option :route_fragment do
          'decommission'
        end

        register_instance_option :http_methods do
          [:get, :delete]
        end

        register_instance_option :authorization_key do
          :destroy
        end

        register_instance_option :controller do
          proc do
            if request.get?

              respond_to do |format|
                format.html { render @action.template_name }
              end

            elsif request.delete?
              redirect_path = nil

              if object.do_decommission()
                flash[:success] = t('admin.flash.successful', name: @model_config.label, action: t('admin.actions.decommission.done'))
                redirect_path = index_path
              else
                flash[:error] = t('admin.flash.error', name: @model_config.label, action: t('admin.actions.decommission.done'))
                redirect_path = back_or_index
              end

              redirect_to redirect_path

            end
          end
        end

        register_instance_option :link_icon do
          # other font icon options:
          #'icon-off'
          #'icon-ban-circle'
          # See app/assets/stylesheets/rails_admin/custom/theming.css.
          # Make sure pipeline caching doesn't interfere in production deployment.
          # May prove helpful to push theming.css through pipeline:
          # bundle exec rake assets:precompile
          'icon-decommission'
        end

        RailsAdmin::Config::Actions.register(self)

      end
    end
  end
end
