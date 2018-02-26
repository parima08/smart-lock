class FirmwaresController < ApplicationController

  force_ssl if: lambda {GojiServer.config.use_ssl_if_possible}

  before_filter :json_authenticate

  respond_to :json

  # POST /firmwares
  def create
    # XXX security: Limit uploads to only developer level sysadmins (role based)
    return render_error(401, "Only system admins can upload a new firmware version") if !@current_account.admin

    if ! GojiServer.config.allow_firmware_upload
      return render_error(401, "Cannot upload a new firmware version on a production server, upload on dev/integration server and add resulting firmwares record to production in seeds.rb at next deployment, or manually if patch release")
    end

    # description could be required too.
    return if params_missing([ :version, :for_external, :file ], params)
    # one replacement, last first, so no pathalogical cases.
    download_url = self.class.gen_download_url(params[:version], params[:for_external])
    # Silently allow replacement of existing firmware file.
    # XXX Needs a transaction!
    Firmware.where(
                     version: params[:version],
                     for_external: params[:for_external]).destroy_all
    Firmware.create!(data: params[:file],
                     version: params[:version],
                     description: params[:description],
                     for_external: params[:for_external],
                     download_url: download_url,
                     uuid: request.uuid)
    render_success
  end

  def self.gen_download_url(version,
                            for_external) # "true"/"false" strings
    Firmware::RELATIVE_PATH
      .sub(":version", version)
      .sub(":for_external",
           Firmware.external_string(ApplicationController.string_to_boolean(for_external)))
  end
end
