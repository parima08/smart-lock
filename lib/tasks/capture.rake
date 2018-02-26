require 'tempfile'

namespace :capture do


  def extract_firmware_records(firmware_class)
    # Would be nice to discard ones already in seeds.rb
    # Or maybe dump to stdout?
    seeds = File.open('db/seeds.rb', "a+")
    seeds.puts "\n\n"
    cnt = 0
    firmware_class.all.each do |rec|
      hash = rec.as_json
      hash.reject! {|k,v| v.nil?} # Remove attributes with value nil, they break Firmware.create()
      seeds.puts "Firmware.create(" + hash.to_json.gsub('":', '"=>') + ")\n"
      cnt += 1
    end
    print cnt.to_s + " records appended to seeds.rb\n"
  end

  desc "Save all firmware records from the current database to seeds.rb."
  task :firmware => [:environment] do
    extract_firmware_records(Firmware)
  end

  desc "Save all firmware records from specifed database access string to seeds.rb."
  task :remote_firmware => [:environment] do
    if !ENV['source']
      print "***** required argument:\n"
      print "source=``\n"
      exit
    end
    print "capturing firmware records from " + ENV['source'] + "\n"
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
    class Source < Firmware
      establish_connection INDB_CONF
    end

    extract_firmware_records(Source)
  end

  desc "Migrate all firmware records from a deployment database to the current database."
  desc "Unfinished, was off-task..."
  # Typically from integration to staging to production.
  task :copy_firmware => [:environment] do

    # XXX read from heroku db config per above...

    Source.all.each do |rec|
      # silently discard ones that already exist.
      Firmware.create(rec.as_json)
    end
  end

end
