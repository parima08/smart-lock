namespace :db do
  task :zap => [:drop, :create, :migrate, :seed, :load_data] do
    print "database zapped\n"
    print "annotating models...\n"
    print `annotate`
    delete_file('coverage')

    Rake::Task["log:clear"].invoke
    print "log cleaned\n"
    Rake::Task["tmp:clear"].invoke
    print "tmp cleaned\n"
  end

end
