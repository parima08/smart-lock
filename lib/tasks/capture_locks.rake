require 'tempfile'

namespace :capture_locks do

  desc "Save all lock records from the current database to locks.rb."
  task :locks => [:environment] do
    extract_records(Account, "Account", "w+")
    extract_records(User, "User", "a+")
    extract_records(Lock, "Lock", "a+")
  end

  desc "Save all lock records from specifed database access string to locks.rb."
  task :remote_locks => [:environment] do
    if !ENV['source']
      print "***** required argument:\n"
      print "source=``\n"
      exit
    end

    vars = ENV['source'].split(/[:\/@]/)
    config = Tempfile.new('tmp.yml')
    config.puts "remote:\n"
    config.puts "  adapter: postgresql\n"
    config.puts "  encoding: latin1\n"
    config.puts "  pool: \n"
    config.puts "  username: #{vars[3]}\n"
    config.puts "  password: #{vars[4]}\n"
    config.puts "  host: #{vars[5]}\n"
    config.puts "  port: #{vars[6]}\n"
    config.puts "  database: #{vars[7]}\n"
    config.rewind
    DB_CONF = YAML::load(config)
    config.close
    config.unlink
    INDB_CONF = DB_CONF['remote']

    class LockSource < Lock
      establish_connection INDB_CONF
    end
    class UserSource < User
      establish_connection INDB_CONF
    end
    class AccountSource < Account
      establish_connection INDB_CONF
    end

    export_records(AccountSource, "Account", "w+")
    export_records(UserSource, "User", "a+")
    export_records(LockSource, "Lock", "a+")
  end

  def export_records(db_class, class_name, mode)
    print "capturing " + class_name + " records from " + ENV['source'] + "\n"
    # This causes error: "Anonymous class is not allowed."
    #source = Class.new(db_class) do
      
    extract_records(db_class, class_name, mode)
  end

  def extract_records(db_class, class_name, mode)
    # Must be run from server src root?
    file = File.open('lib/tasks/locks.rb', mode)

=begin
  {:email  => 'glenn.widener@room5.com',
      :name            => "GlennW's Door",
      :orientation        => "left",
      :commission_date => Time.yes
      :bluetooth_address  => "LOCK-GLEN"
  },
=end
    file.puts "REAL_" + class_name + " = [\n"
    cnt = 0
    db_class.all.each do |rec|
      # Save non-public attributes
      hash = rec.attributes.symbolize_keys
      hash.reject! {|k,v| v.nil?} # Ignore attributes with value nil
      # I think it's a bug that hash.to_s doesn't put quotes around Date.to_s.
      hash.each { |k, v| hash[k] = v.to_s }
      file.puts hash.to_s + ",\n"
      cnt += 1
    end
    file.puts "]\n"
    file.close
    print cnt.to_s + " records stored in locks.rb\n"
  end

end
