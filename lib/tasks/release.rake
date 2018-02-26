namespace :release do
  desc "push production branch to goji-server (production)"
  task :production => [:environment] do
    begin
      # with_clean_env is important to avoid issues with heroku toolbelt vendored ruby
      # see : https://github.com/sstephenson/rbenv/issues/400    
      Bundler.with_clean_env do 
        print "pushing production to heroku (http://goji-server.herokuapp.com)...\n"
        print `git push production production:master`
        # uncomment to reset production database
        #print "WARNING ! Resetting database...\n"
        # print `heroku pg:reset HEROKU_POSTGRESQL_VIOLET_URL --app goji-server --confirm goji-server`
        print "migrating database...\n"
        print `heroku run rake db:migrate --app goji-server`
        #print "loading data ...\n"
        #print `heroku run rake db:load_data --app goji-server`
        print `heroku run rake airbrake:deploy TO=production --app goji-server`
        print "Notification email sent to 'ahoggett@emmoco.com, cwalden@emmoco.com'...\n" 
      end
    rescue Exception => e
      print "The production release failed due to an unexpected error details follow... \n"
      print "#{e.backtrace}\n"
      print "The production release was unsuccessful. \n"
    end 
  end

  desc "push staging branch to goji-server-staging"
  task :staging => [:environment] do
    begin
      Bundler.with_clean_env do 
        print "pushing staging to heroku (http://goji-server-staging.herokuapp.com)...\n"
        print `git push staging staging:master`
        # uncomment/comment 2 lines below to reset staging database
        #print "WARNING ! Resetting database...\n"
        #print `heroku pg:reset HEROKU_POSTGRESQL_MAROON_URL --app goji-server-staging --confirm goji-server-staging`
        print "migrating database...\n"
        print `heroku run rake db:migrate --app goji-server-staging`
        # uncomment/comment 3 lines below to load demo data into staging database 
        #print "loading data ...\n"
        #print `heroku run rake db:load_data --app goji-server-staging`
        print `heroku run rake airbrake:deploy TO=staging --app goji-server-staging`
        print "Notification email sent to 'ahoggett@emmoco.com, cwalden@emmoco.com'...\n"
      end
    rescue Exception => e
      print "The staging release failed due to an unexpected error details follow... \n"
      print "#{e.backtrace}\n"
      print "The staging release was unsuccessful. \n" 
    end
  end
end
