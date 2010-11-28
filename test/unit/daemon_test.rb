require 'test_helper'

class DaemonTest < ActiveSupport::TestCase
  setup :setup_paths

  test "daemon options" do
    start_daemon(:application_root => @app_root_path)

    wait_for_file(@log_path)

    assert File.read(@log_path).match('INFO -- : Job Boss started')

    stop_daemon


    custom_log_path = File.join('log', 'loggity.log')
    full_custom_log_path = File.join(@app_root_path, custom_log_path)

    start_daemon(:application_root => @app_root_path, :log_path => custom_log_path, :environment => 'production')
    wait_for_file(full_custom_log_path)

    assert File.read(full_custom_log_path).match('INFO -- : Job Boss started')
    assert File.exist?(File.join(@app_root_path, 'db', 'production.sqlite3'))

    restart_daemon

    stop_daemon


  end
end
