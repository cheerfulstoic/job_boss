require 'rubygems'
require 'test/unit'
require 'sqlite3'

require 'fileutils'
FileUtils.cd(File.expand_path('../..', __FILE__))

require 'active_support'

class ActiveSupport::TestCase
  # Add more helper methods to be used by all tests here...

  def setup_paths
    @app_root_path = File.join('test', 'app_root')
    @db_path = File.join(@app_root_path, 'db')
    @log_path = File.join(@app_root_path, 'log', 'job_boss.log')
  end

  def clean_app_environment
    Dir.glob(File.join(@db_path, '*')).each {|path| File.unlink(path) }
    Dir.glob(File.join(@app_root_path, 'log', '*')).each {|path| File.unlink(path) }
  end

  def start_daemon(options)
    clean_app_environment

    stop_daemon

    option_string = options.collect do |key, value|
      '--' + key.to_s.gsub('_', '-') + " " + value.to_s
    end

    `bin/job_boss start -- #{option_string.join(' ')}`
  end

  def wait_for_file(file_path, wait_time = 5)
    i = 0
    until File.exist?(file_path)
      sleep(1)

      raise "File failed to appear!" if i > wait_time
      i += 1
    end
  end

  def stop_daemon
    `bin/job_boss stop`
  end
end