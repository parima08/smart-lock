//for sysadmin/account edit pages
//= require_tree .

//for sysadmin admin pages
$(document).on("rails_admin.dom_ready", function(){
    function railsAdminStrengthCheck(passwordItem, emailItem, entropyItem){
       $(passwordItem).after( '<div class = "progress" style= "width: 370px"><div id="password_strength_progress_bar" class = "progress-bar">' + 
            '</div></div>' + 
            '<div id="password_strength_msg"></div>');
        var pws = $(entropyItem)
        $("#password_strength_progress_bar").zxcvbnProgressBar({
              passwordInput: passwordItem,
              email: emailItem,
              message: '#password_strength_msg',
              recordEntropy: entropyItem,
              submit: "button[name='_save']",
              rails_admin: true,
        });
    }
    railsAdminStrengthCheck("#account_password", 
			    "#account_email",
			    "#account_password_entropy_percent");
    railsAdminStrengthCheck("#sysadmin_users_password",
			    "#sysadmin_users_email",
			    "#sysadmin_users_password_entropy_percent");
});