# config/unicorn.rb

require 'fileutils'
preload_app true
timeout 30 # 30 seconds, then restart unicorn worker
worker_processes Integer(ENV["WEB_CONCURRENCY"] || 3)

listen '/tmp/nginx.socket', backlog: 1024

before_fork do |server, worker|

  FileUtils.touch('/tmp/app-initialized')

  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end

  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.connection.disconnect!
end

after_fork do |server, worker|

  if defined?(ActiveRecord::Base)
    config = Rails.application.config.database_configuration[Rails.env]
    config['reaping_frequency'] = ENV['DB_REAP_FREQ'] || 10 # seconds
    config['pool']              = ENV['DB_POOL'] || 6
  end

  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to sent QUIT'
  end

  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection
end

