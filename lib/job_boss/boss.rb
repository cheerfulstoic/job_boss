module JobBoss
  class Boss
    class JobBossConfig
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

    def self.config
      @@config = JobBossConfig.new
    end

    def initialize(options = {})
      @@config.working_dir          ||= options[:working_dir]
      @@config.sleep_interval       ||= options[:sleep_interval]
      @@config.employee_limit       ||= options[:employee_limit]
      @@config.database_yaml_path   ||= options[:database_yaml_path]
      @@config.jobs_path            ||= options[:jobs_path]

      @running_jobs = []
    end

    def cleanup_running_jobs
      Job.uncached do
        @running_jobs = Job.running.where('id in (?)', @running_jobs)
      end
    end

    def available_children
      cleanup_running_jobs

      @@config.employee_limit - @running_jobs.size
    end

    def connect
      @@config.database_yaml_path = File.join(@@config.working_dir, @@config.database_yaml_path) unless @@config.database_yaml_path[0] == ?/

      raise "Database YAML file missing (#{@@config.database_yaml_path})" unless File.exist?(@@config.database_yaml_path)

      config = YAML.load(File.read(@@config.database_yaml_path))

      ActiveRecord::Base.establish_connection(config[@@config.environment])
    end

    def require_job_classes
      @@config.jobs_path = File.join(@@config.working_dir, @@config.jobs_path) unless @@config.jobs_path[0] == ?/

      Dir.glob(File.join(@@config.jobs_path, '*.rb')).each {|job_class| require job_class }
    end

    def start
      require 'active_record'
      require 'yaml'

      connect

      require_job_classes

      require 'job_boss/job'

      Signal.trap("HUP") do
        self.stop
      end

      at_exit { self.stop }

      puts "Job Boss started"

      while true
        unless (children_count = available_children) > 0 && Job.pending.count > 0
          sleep(@@config.sleep_interval)
          next
        end

        Job.pending_paths.each do |path|
          job = Job.pending.find_by_path(path)
          next if job.nil?

          job.dispatch
          @running_jobs << job

          children_count -= 1
          break unless children_count > 0
        end

      end
    end

    def shutdown_running_jobs
      cleanup_running_jobs

      @running_jobs.each do |job|
        job.kill
        job.mark_for_redo
      end
    end

    def stop
      puts "Stopping #{@running_jobs.size} running employees..."

      shutdown_running_jobs

      puts "Job Boss stopped"
    end
  end
end