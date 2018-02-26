class StoreController < ApplicationController
  respond_to :html
  layout false # TODO LP19814677 Make a common store layout

  # Redirect to the appropriate Goji store/app.
  # For alpha AppBlade, one url.
  APP_BLADE = "http://email.appblade.com/wf/click?upn=N97kWvjGSJs4ZffNO9vFGnUJb5QuPe6OTRW9xkRRQdn3y6U1-2FQTZrWo-2F-2B29knXqVCvrh-2BjI2XyMH5BdEDleyK394kaHDX8hvcNW1KpGnczJHW3RZeMh1AD8vfls7FJ6-2B_e8V7EOQTGNPs-2Fqi5Xfx2jpLigV4ISv1nKcyJ6HVVM-2F1DbwuXk5v2kxy9prG-2Bl-2Fw4PGJRiJFgt0P82f4J5SwX-2B-2BzejsfJaNVwWv2CcGGR0hVhofUEqb8W89jFt69UKFo9ZcszyGmyPVpiEVKb7i5wKvgq0bc1cfseMZhcW2qFIlvrEDQqXMxQGcA8hJGomwuhjnlDMLfMwnWo-2FlNLs5JLqSaZyeM8SZX-2BZfy5jzGg0E3O5pEqhcBbkoUQOwyzxgcl"
  def index
    key_id=params[:key_id]
    email=params[:email]
    password=params[:password]

    browser = Browser.new(:ua => request.user_agent,
                          :accept_language => "en-us")
    # TBD: Try the indirect installation from iTunes/Mac.
    if browser.ios? # || browser.mac?
      redirect_to(APP_BLADE, status: 302)
      #redirect_to("http://ios store/app/?keyid, email, tpass", status: 302)
    elsif browser.android?
      redirect_to(APP_BLADE, status: 302)
      # XXX escape "="?
      #redirect_to("http://android store?id=app_name&referrer={keyid:#{key_id},email:#{email},tpass#{password}:}", status: 302)
    else
      # Instruct the user to view email on Android/iPhone
      # Prevent showing admin site nav in application.html.erb.
      @standalone = true
      #redirect_to("http://www.gojiaccess.com/shop-goji.html", status: 302)
    end
  end

  def go
    # For safety, we're only allowing through the parameters we'll use
    values = params.permit(:key_id, :email, :confirmation_token, :reset_password_token)

    @android_store_url = APP_BLADE
    @apple_url         = APP_BLADE
    browser = Browser.new(:ua => request.user_agent, :accept_language => "en-us")
    if browser.ios?
      @ios = true
      check_browser_version(browser.full_version, "iOS", 7.0, request.user_agent)
      @redirection_url   = "goji://?" + values.to_query
    elsif browser.android?
      @android = true
      version = request.user_agent.scan(/Android (\d+(?:\.\d+)+)/)[0][0]
      # we only support < kitkat (4.4) - lollipop (5.0)
      check_browser_version(version, "Android" , 4.4, request.user_agent)
      @redirection_url   = "intent://?" + values.to_query + "#Intent;scheme=goji;package=com.gojiaccess.android;end"
    else
      @mobile = false
      @msg = "Please view this email on an iOS/Android device."
    end
  end

  def device_confirmation
    if !params[:id].present? || !params[:device_confirmation_token].present?
      @msg = "Invalid Request"
      @extended_msg = "Missing Required Parameters. Please try opening the link again from the email."
      render status: :unprocessable_entity
      return
    end

    # TODO rename DB column to device_confirmation_token Let's keep these separate all the way through the system
    @user_device = UserDevice.where(id: params[:id]).first

    if !@user_device || !Devise.secure_compare(@user_device.confirmation_token, params[:device_confirmation_token])
      @msg = "Invalid Request"
      @extended_msg = "The token or device was not found. Please check to make sure you are opening the full link from the email."
      render status: :not_found
      return
    end

    @user_device.mark_as_confirmed

    if @user_device.save
      @msg = "Device Confirmed"
      @extended_msg = "Please continue logging in on your new device."
      render
    else
      # TODO standardize this for human facing pages
      # TODO include UUID for support purposes
      @msg = "Internal Error"
      @extended_msg = "Please try again in a few minutes or contact support for more assistance"
      render status: :internal_server_error
    end
  end

  private
  def check_browser_version(version, os, min, ua)
    # Browser gem doesn't handle ipod (not really supported except as a test tool:
    # UA:Mozilla/5.0 (iPod touch; CPU iPhone OS 7_1_2 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Mobile/11D257
    version = ua[/iPhone OS ([^ ]*)/, 1].gsub('_', '.') if ua.include?("iPod")
    if (Gem::Version.new(version) < Gem::Version.new(min))
      @mobile = false
      @msg = "We only support #{os} #{min} and higher."
      #logger.debug("unsupported " + os + " browser version=" + version)
      return
    end
    @mobile = true
    @msg = "Redirecting to Goji app... if the application doesn't open automatically, click the button below:"
  end

end
