class Mailer < ActionMailer::Base

  # We will revist whether to make the email "from", and reply-able-to, the
  # sender's email, after alpha.  If not, this should be a real email
  # account and send an auto-reply: "Click the red button (please)"!
  @@FAKE_FROM = "noreply@gojiaccess.com"

  @@SUBJECTS =  {
    key_shared: 'Smart Lock Invitation',
    lock_decommissioned: 'Smart Lock out of service',
    admin_shared: 'Smart Lock access upgraded',
    admin_revoked: 'Smart Lock access changed',
    key_revoked: 'Smart Lock access canceled',
    access_changed: 'Smart Lock access times changed',
    user_device_confirmed: 'Your new mobile device must be confirmed'
  }

  def self.subjects(event_type)
    @@SUBJECTS[event_type.to_sym]
  end

  default :from =>  @@FAKE_FROM
  default :sender => @@FAKE_FROM

  def gen_button_url(extra, event_type)
     if (event_type && (event_type == EventType::USER_DEVICE_CONFIRMED))
      url_for(controller: 'store',
      action: 'device_confirmation',
      device_confirmation_token: extra ? extra[:confirmation_token]: "",
      id: extra ? extra[:id]: "",
      only_path: false )
    else
      url_for(controller: 'store', only_path: false)
    end
  end

  def gen_root_url(extra)
    # Fortunately (or ugly!), the mailer is also configured with server url.
    # Comes from MAILER_URL/config.action_mailer.default_url_options, includes port.
    # Undocumented method, can't call url_for except on a configured route.
    root_url
    #"http://" + extra[:host] + ":" + extra[:port].to_s
  end

  def send_email(event_type, lock, key, # nil on admin events
                 from_user,
                 to_user,
                 extra, # unused now
                 password) # nil if not ADMIN_SHARED+new account
    @key = key
    @lock = lock
    @email = to_user.account.email
    @from = from_user ? from_user.account.full_name : "Goji Support"
    @owner = lock.user.account if (lock && lock.user)
    @subject = self.class.subjects(event_type)
    @password = password
    @url = gen_button_url(extra, event_type)
    @root_url = gen_root_url(extra)
    if event_type == EventType::USER_DEVICE_CONFIRMED
      @instructions="You have requested addition of a new mobile device to your Goji Smart lock account."
    else
      @instructions="To view your lock access, open your Goji App."
    end
    @instr="Open the Goji App"
    if (event_type == EventType::KEY_SHARED)
      template = password ?
        ((lock.user == from_user) ? # not Admin share
         'key_shared_new_account_email' :
         'key_shared_new_account_email_from_admin') :
        ((lock.user == from_user) ?
         'key_shared_email' :
         'key_shared_email_from_admin')
    else
      template = event_type + '_email'
    end
    mail(to: to_user.account.email,
         # Safe full_name when account not confirmed yet (should not happen except when hacking from admin ui):
         from: @from + " via Goji Smart Lock <" + @@FAKE_FROM + ">",
         subject: @subject,
         template_name: template)
  end

end
