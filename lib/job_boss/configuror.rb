module JobBoss
  class Config
    attr_accessor :working_dir, :database_yaml_path, :jobs_path, :sleep_interval, :employee_limit, :environment

    def parse_args(argv, options = {})
      @working_dir          = options[:working_dir] || Dir.pwd
      @database_yaml_path   = 'config/database.yml'
      @jobs_path            = 'app/jobs'
      @sleep_interval       = 0.5
      @employee_limit       = 4
      @environment          = 'development'

      require 'optparse'

      OptionParser.new do |opts|
        opts.banner = "Usage: job_boss [start|stop|restart|status|watch] [-- <options>]"

        opts.on("-d", "--database-yaml PATH", "Path for database YAML (defaults to ./config/database.yml)") do |path|
          @database_yaml_path = path
        end

        opts.on("-j", "--jobs-path PATH", "Path to folder with job classes (defaults to ./app/jobs)") do |path|
          @database_yaml_path = path
        end

        opts.on("-e", "--environment ENV", "Rails environment to use in database YAML file (defaults to 'development')") do |env|
          @environment = env
        end

        opts.on("-s", "--sleep-interval INTERVAL", Integer, "Number of seconds for the boss to sleep between checks of the queue (default 0.5)") do |interval|
          @sleep_interval = interval
        end

        opts.on("-c", "--child-limit LIMIT", Integer, "Maximum number of employees (default 4)") do |limit|
          @employee_limit = limit
        end
      end.parse!(argv)
    end
  end
end