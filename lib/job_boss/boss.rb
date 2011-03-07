require 'active_support'

module JobBoss
  class Boss
    extend ActiveSupport::Memoizable

    class << self
      extend ActiveSupport::Memoizable
      # Used to set Boss configuration
      # Usage:
      #   Boss.config.sleep_interval = 2
      def config
        require 'job_boss/config'
        Config.new
      end
      memoize :config

      # Used to queue jobs
      # Usage:
      #   Boss.queue.math.is_prime?(42)
      def queue(attributes = {})
        require 'job_boss/queuer'
        Queuer.new(attributes)
      end
      memoize :queue

      # Used to queue jobs
      # Usage:
      #   Boss.queue_path('math#in_prime?', 42)
      def queue_path(path, *args)
        controller, action = path.split('#')

        queue.send(controller).send(action, *args)
      end

      # If path starts with '/', leave alone.  Otherwise, prepend application_root
      def resolve_path(path)
        if path == ?/ || path.match(/^#{config.application_root}/)
          path
        else
          File.join(config.application_root, path)
        end
      end
    end

    def config
      Boss.config
    end

    def logger
      config.log_path = Boss.resolve_path(config.log_path)

      require 'logger'
      Logger.new(config.log_path)
    end
    memoize :logger

    def initialize(options = {})
      config.application_root     ||= options[:working_dir]
      config.sleep_interval       ||= options[:sleep_interval]
      config.employee_limit       ||= options[:employee_limit]
      config.database_yaml_path   ||= options[:database_yaml_path]
      config.jobs_path            ||= options[:jobs_path]

      @running_jobs = []
    end

    # Start the boss
    def start
      require 'active_record'
      require 'yaml'

      establish_active_record_connection
      logger.info "Started ActiveRecord connection in '#{config.environment}' environment from database YAML: #{config.database_yaml_path}"

      require_job_classes

      Signal.trap("HUP") do
        stop
      end

      at_exit do
        stop if Process.pid == BOSS_PID
      end

      logger.info "Job Boss started"
      logger.info "Employee limit: #{Boss.config.employee_limit}"

      jobs = []
      while true
        available_employee_count = wait_for_available_employees

        if jobs.empty?
          jobs = dequeue_jobs
          jobs.each {|job| job.update_attributes(:started_at => Time.now) }
        end

        [available_employee_count, jobs.size].min.times do
          job = jobs.shift
          job.dispatch(self)
          @running_jobs << job
        end

      end
    end

    # Waits until there is at least one available employee and then returns count
    def wait_for_available_employees
      until (employee_count = available_employees) > 0 && Job.pending.count > 0
        sleep(config.sleep_interval)
      end

      employee_count
    end

    # Dequeues next set of jobs based on prioritized round robin algorithm
    # Priority of a particular queue determines how many jobs get pulled from that queue each time we dequeue
    # A priority adjustment is also done to give greater priority to sets of jobs which have been running longer
    def dequeue_jobs
      logger.info "Dequeuing jobs"
      Job.pending.select('DISTINCT priority, path, batch_id').reorder(nil).collect do |distinct_job|
        queue_scope = Job.where(:path => distinct_job.path, :batch_id => distinct_job.batch_id)

        # Give queues which have are further along more priority to reduce latency
        priority_adjustment = ((queue_scope.completed.count.to_f / queue_scope.count) * config.employee_limit).floor

        queue_scope.pending.limit(distinct_job.priority + priority_adjustment)
      end.flatten.sort_by(&:id)
    end

    def stop
      logger.info "Stopping #{@running_jobs.size} running employees..."

      shutdown_running_jobs

      logger.info "Job Boss stopped"
    end

private
    # Cleans up @running_jobs variable, getting rid of jobs which have
    # completed, which have been cancelled, or which went MIA
    def cleanup_running_jobs
      Job.uncached do
        @running_jobs = Job.running.where('id in (?)', @running_jobs)

        cancelled_jobs = @running_jobs.select(&:cancelled?)
        cancelled_jobs.each do |job|
          logger.warn "Cancelling job ##{job.id}"
          kill_job(job)
        end
        @running_jobs -= cancelled_jobs

        # Clean out any jobs whos processes have stopped running for some reason
        @running_jobs = @running_jobs.select do |job|
          begin
            Process.kill(0, job.employee_pid.to_i)
          rescue Errno::ESRCH
            logger.warn "Job ##{job.id} MIA!"
            job.mark_as_mia
            nil
          end
        end
      end
    end

    # Total number of employees which can be run
    def available_employees
      cleanup_running_jobs

      config.employee_limit - @running_jobs.size
    end

    def establish_active_record_connection
      config.database_yaml_path = Boss.resolve_path(config.database_yaml_path)

      raise "Database YAML file missing (#{config.database_yaml_path})" unless File.exist?(config.database_yaml_path)

      config_data = YAML.load(File.read(config.database_yaml_path))

      ActiveRecord::Base.remove_connection
      ActiveRecord::Base.establish_connection(config_data[config.environment])

      require 'job_boss/job'
      unless Job.table_exists?
        Job.transaction do
          require 'migrate'
          CreateJobs.up
        end
      end
    end

    def require_job_classes
      config.jobs_path = Boss.resolve_path(config.jobs_path)

      raise "Jobs path missing (#{config.jobs_path})" unless File.exist?(config.jobs_path)

      Dir.glob(File.join(config.jobs_path, '*.rb')).each {|job_class| require job_class }
    end

    def kill_job(job)
      begin
        Process.kill("TERM", job.employee_pid.to_i)
      rescue Errno::ESRCH
        logger.error "Could not kill job ##{job.id}!"
        nil
      end
    end

    def shutdown_running_jobs
      cleanup_running_jobs

      @running_jobs.each do |job|
        kill_job(job)
        job.mark_for_redo
      end
    end
  end
end