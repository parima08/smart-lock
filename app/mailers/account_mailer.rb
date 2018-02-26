class AccountMailer < Devise::Mailer
  helper :application
  layout 'mailer'

  include Devise::Controllers::UrlHelpers

  # This mailer is used by Devise for all automated messages
  # Therefore, the interesting parts come from the parent class
  # 
  # Should we need to override methods, the following style could be used:
  #
  # def confirmation_instructions(record, opts={})
  #  Setup custom stuff/variables here
  #  super
  # end

end
