require 'test_helper'

class DaemonTest < ActiveSupport::TestCase
  test "Basic startup/shutdown" do
    start_daemon(:application_root => @app_root_path)

    wait_for_file(@log_path)

    log_output = File.read(@log_path)
    assert log_output.match("INFO -- : Started ActiveRecord connection in 'development' environment from database YAML: #{@db_yaml_path}")
    assert log_output.match('INFO -- : Job Boss started')
    assert log_output.match('INFO -- : Employee limit: 4')
    

    stop_daemon
  end

  test "Startup/shutdown with environment variables" do
    ENV['JB_APPLICATION_ROOT'] = @app_root_path
    ENV['JB_EMPLOYEE_LIMIT'] = '2'
    start_daemon

    wait_for_file(@log_path)

    log_output = File.read(@log_path)
    assert log_output.match("INFO -- : Started ActiveRecord connection in 'development' environment from database YAML: #{@db_yaml_path}")
    assert log_output.match('INFO -- : Job Boss started')
    assert log_output.match('INFO -- : Employee limit: 2')

    stop_daemon

    ENV['JB_APPLICATION_ROOT'] = nil
    ENV['JB_EMPLOYEE_LIMIT'] = nil
  end

  test "Startup with different command line options" do
    custom_log_path = File.join('log', 'loggity.log')
    full_custom_log_path = File.join(@app_root_path, custom_log_path)

    ENV['JB_EMPLOYEE_LIMIT'] = '2' # Make sure application setting overrides environment variable
    start_daemon(:application_root => @app_root_path, :log_path => custom_log_path, :environment => 'production', :employee_limit => 3)
    wait_for_file(full_custom_log_path)

    log_output = File.read(full_custom_log_path)
    assert log_output.match("INFO -- : Started ActiveRecord connection in 'production' environment from database YAML: #{@db_yaml_path}")
    assert log_output.match('INFO -- : Job Boss started')
    assert log_output.match('INFO -- : Employee limit: 3')
    assert File.exist?(File.join(@app_root_path, 'db', 'production.sqlite3'))

    restart_daemon

    stop_daemon

    ENV['JB_EMPLOYEE_LIMIT'] = nil
  end
end
