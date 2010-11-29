require 'rubygems'
require 'test/unit'
require 'sqlite3'

require 'fileutils'
FileUtils.cd(File.expand_path('../..', __FILE__))

require 'active_support'

class ActiveSupport::TestCase
  # Add more helper methods to be used by all tests here...

  setup :setup_paths
  teardown :clean_app_environment
  teardown :stop_daemon

  def setup_paths
    @app_root_path = File.join('test', 'app_root')
    @db_path = File.join(@app_root_path, 'db')
    @log_path = File.join(@app_root_path, 'log', 'job_boss.log')
    @db_yaml_path = File.join(@app_root_path, 'config', 'database.yml')
  end

  def clean_app_environment
    Dir.glob(File.join(@db_path, '*')).each {|path| File.unlink(path) }
    Dir.glob(File.join(@app_root_path, 'log', '*')).each {|path| File.unlink(path) }
  end

  def assert_pid_running(pid, message="")
    full_message = build_message(message, "PID <?> expected to be running.", pid)
    assert_block(full_message) do
      begin
        Process.kill(0, pid.to_i)
        true
      rescue
        false
      end
    end
  end

  def assert_pid_not_running(pid, message="")
    full_message = build_message(message, "PID <?> expected to not be running.", pid)
    assert_block(full_message) do
      begin
        Process.kill(0, pid.to_i)
        false
      rescue
        true
      end
    end
  end

  def start_daemon(options)
    clean_app_environment

    stop_daemon

    option_string = options.collect do |key, value|
      '--' + key.to_s.gsub('_', '-') + " " + value.to_s
    end

    output = `bin/job_boss start -- #{option_string.join(' ')}`

    @daemon_pid = get_pid_from_startup(output)

    assert_pid_running(@daemon_pid)

    @daemon_pid
  end

  def get_pid_from_startup(output)
    output.match(/job_boss: process with pid (\d+) started./)[1].to_i
  end

  def wait_for_file(file_path, timeout = 5)
    i = 0
    until File.exist?(file_path)
      sleep(1)

      raise "File failed to appear!" if i > timeout
      i += 1
    end
  end

  def wait_until_job_assigned(job, wait_interval = 0.5)
    until job.assigned?
      sleep(wait_interval)
      job.reload
    end
  end

  def stop_daemon
    `bin/job_boss stop`

    # Give the daemon a bit of time to stop
#    sleep(0.5)
    assert_pid_not_running(@daemon_pid) if @daemon_pid
  end

  def restart_daemon
    assert_pid_running(@daemon_pid)

    output = `bin/job_boss restart`

    # Give the daemon a bit of time to stop
#    sleep(0.5)
    assert_pid_not_running(@daemon_pid)

    @daemon_pid = get_pid_from_startup(output)

    assert_pid_running(@daemon_pid)
  end
end
