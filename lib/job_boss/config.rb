require 'active_support/core_ext/string'

module JobBoss
  class Config
    attr_accessor :application_root, :database_yaml_path, :log_path, :jobs_path, :sleep_interval, :employee_limit, :environment

    def parse_args(argv, options = {})
      @application_root     = File.expand_path(ENV['JB_APPLICATION_ROOT'] || options[:working_dir] || Dir.pwd)
      @database_yaml_path   = ENV['JB_DATABASE_YAML_PATH'] || 'config/database.yml'
      @log_path             = ENV['JB_LOG_PATH'] || 'log/job_boss.log'
      @jobs_path            = ENV['JB_JOBS_PATH'] || 'app/jobs'
      @sleep_interval       = ENV['JB_SLEEP_INTERVAL'].blank? ? 0.5 : ENV['JB_SLEEP_INTERVAL'].to_f
      @employee_limit       = ENV['JB_EMPLOYEE_LIMIT'].blank? ? 4 : ENV['JB_EMPLOYEE_LIMIT'].to_i
      @environment          = ENV['JB_ENVIRONMENT'] || ENV['RAILS_ENV'] || 'development'

      require 'optparse'

      OptionParser.new do |opts|
        opts.banner = "Usage: job_boss [start|stop|restart|run|zap] [-- <options>]"

        opts.on("-r", "--application-root PATH", "Path for the application root upon which other paths depend (defaults to .)  Environment variable: JB_APPLICATION_ROOT") do |path|
          @application_root = File.expand_path(path)
        end

        opts.on("-d", "--database-yaml PATH", "Path for database YAML (defaults to <application-root>/#{@database_yaml_path}) Environment variable: JB_DATABASE_YAML_PATH") do |path|
          @database_yaml_path = path
        end

        opts.on("-l", "--log-path PATH", "Path for log file (defaults to <application-root>/#{@log_path}) Environment variable: JB_LOG_PATH") do |path|
          @log_path = path
        end

        opts.on("-j", "--jobs-path PATH", "Path to folder with job classes (defaults to <application-root>/#{@jobs_path}) Environment variable: JB_JOBS_PATH") do |path|
          @jobs_path = path
        end

        opts.on("-e", "--environment ENV", "Environment to use in database YAML file (defaults to '#{@environment}') Environment variable: JB_ENVIRONMENT") do |env|
          @environment = env
        end

        opts.on("-s", "--sleep-interval INTERVAL", Integer, "Number of seconds for the boss to sleep between checks of the queue (default #{@sleep_interval}) Environment variable: JB_SLEEP_INTERVAL") do |interval|
          @sleep_interval = interval
        end

        opts.on("-c", "--employee-limit LIMIT", Integer, "Maximum number of employees (default 4) Environment variable: JB_EMPLOYEE_LIMIT") do |limit|
          @employee_limit = limit
        end
      end.parse!(argv)
    end
  end
end