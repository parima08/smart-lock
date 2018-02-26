class Ability
  include CanCan::Ability

  def initialize(account)
    @account = account || Account.new # for guest
    @account.roles.each { |role| send(role) }

    if @account.roles.size == 0
      can :access, :rails_admin
      can :dashboard
    end
  end

  def customer_support
    can :access, :rails_admin
    can :dashboard
    # we can fine tune these features even further if we don't 
    # want a user to be able to, for instance, decommission a lock. 
    can :manage, [SysadminUsers, LockManagement, KeyManagement, DeviceManagement]
  end
  
  def firmware_uploader
    can :access, :rails_admin
    can :dashboard
    can :manage, Firmware
    can :manage, FirmwareVersions
  end

  def sysadmin
    can :access, :rails_admin
    can :dashboard
    #what happens when you have a sysadmin + firmware_uploader
    can :manage, :all
    cannot :manage, Firmware
    cannot :manage, FirmwareVersions
  end
end
