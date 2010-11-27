module JobBoss
  class Config
    attr_accessor :application_root, :database_yaml_path, :log_path, :jobs_path, :sleep_interval, :employee_limit, :environment

    def parse_args(argv, options = {})
      @application_root     = options[:working_dir] || Dir.pwd
      @database_yaml_path   = 'config/database.yml'
      @log_path             = 'log/job_boss.log'
      @jobs_path            = 'app/jobs'
      @sleep_interval       = 0.5
      @employee_limit       = 4
      @environment          = 'development'

      require 'optparse'

      OptionParser.new do |opts|
        opts.banner = "Usage: job_boss [start|stop|restart|status|watch] [-- <options>]"

        opts.on("-r", "--application-root PATH", "Path for the application root upon which other paths depend (defaults to .)") do |path|
          @application_root = path
        end

        opts.on("-d", "--database-yaml PATH", "Path for database YAML (defaults to <application-root>/#{@database_yaml_path})") do |path|
          @database_yaml_path = path
        end

        opts.on("-l", "--log-path PATH", "Path for log file (defaults to <application-root>/#{@log_path})") do |path|
          @log_path = path
        end

        opts.on("-j", "--jobs-path PATH", "Path to folder with job classes (defaults to <application-root>/#{@jobs_path})") do |path|
          @jobs_path = path
        end

        opts.on("-e", "--environment ENV", "Environment to use in database YAML file (defaults to '#{@environment}')") do |env|
          @environment = env
        end

        opts.on("-s", "--sleep-interval INTERVAL", Integer, "Number of seconds for the boss to sleep between checks of the queue (default #{@sleep_interval})") do |interval|
          @sleep_interval = interval
        end

        opts.on("-c", "--child-limit LIMIT", Integer, "Maximum number of employees (default 4)") do |limit|
          @employee_limit = limit
        end
      end.parse!(argv)
    end
  end
end