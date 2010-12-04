
module JobBoss
  class Job < ActiveRecord::Base
    default_scope order('created_at')

    serialize :args
    serialize :result
    serialize :error_backtrace

    scope :pending, where('started_at IS NULL AND cancelled_at IS NULL')
    scope :running, where('started_at IS NOT NULL AND completed_at IS NULL')
    scope :completed, where('completed_at IS NOT NULL')

    # Method used by the boss to dispatch an employee
    def dispatch
      mark_as_started
      Boss.logger.info "Dispatching Job ##{self.id}"

      pid = fork do
        ActiveRecord::Base.connection.reconnect!
        $0 = "[job_boss] employee (job ##{self.id})"
        Process.setpriority(Process::PRIO_PROCESS, 0, 19)

        begin
          mark_employee

          value = self.class.call_path(self.path, *self.args)

          self.update_attribute(:result, value)
        rescue Exception => exception
          mark_exception(exception)
          Boss.logger.error "Error running job ##{self.id}!"
        ensure
          until mark_as_completed
            sleep(1)
          end

          Boss.logger.info "Job ##{self.id} completed, exiting..."
          Kernel.exit
        end
      end
      Process.detach(pid)
      ActiveRecord::Base.connection.reconnect!
    end

    # Store result as first and only value of an array so that the value always gets serialized
    # Was having issues with the boolean value of false getting stored as the string "f"
    def result=(value)
      write_attribute(:result, [value])
    end

    def result
      # If the result is being called for but the job hasn't been completed, reload
      # to check to see if there was a result
      self.reload if !completed? && read_attribute(:result).nil?

      value = read_attribute(:result)

      value.is_a?(Array) ? value.first : value
    end

    # Clear out the job and put it back onto the queue for processing
    def mark_for_redo
      self.reload
      self.started_at = nil
      self.result = nil
      self.completed_at = nil
      self.status = nil
      self.error_message = nil
      self.error_backtrace = nil
      self.employee_host = nil
      self.employee_pid = nil
      self.save
    end

    # Is the job complete?
    def completed?
      !!completed_at
    end

    # Mark the job as cancelled so that the boss won't run the job and so that
    # the employee running the job gets stopped (if it's been dispatched)
    def cancel
      mark_as_cancelled
    end

    # Has the job been cancelled?
    def cancelled?
      !!cancelled_at
    end

    # Did the job succeed?
    def succeeded?
      completed_at && (status == 'success')
    end

    # Has the job been assigned to an employee?
    def assigned?
      # If the #assigned? method is being called for but the job hasn't been completed, reload
      # to check to see if it has been assigned
      self.reload if !completed? && employee_pid.nil?

      employee_pid && employee_host
    end

    # How long did the job take?
    def time_taken
      completed_at - started_at if completed_at && started_at
    end

    # If the job raised an exception, this method will return the instance of that exception
    # with the message and backtrace
    def error
      # If the error is being called for but the job hasn't been completed, reload
      # to check to see if there was a error
      self.reload if !completed? && error_message.nil?

      if error_class && error_message && error_backtrace
        error = Kernel.const_get(error_class).new(error_message)
        error.set_backtrace(error_backtrace)
        error
      end
    end

    class << self
      def wait_for_jobs(jobs, sleep_interval = 0.5)
        jobs = [jobs] if jobs.is_a?(Job)

        ids = jobs.collect(&:id)
        Job.uncached do
          until Job.completed.find_all_by_id(ids).count == jobs.size
            sleep(sleep_interval)
          end
        end

        true
      end

      def result_hash(jobs)
        jobs = [jobs] if jobs.is_a?(Job)

        # the #result method automatically reloads the result here if needed but this will
        # do it in one SQL call
        jobs = Job.find(jobs.collect(&:id))

        require 'yaml'
        jobs.inject({}) do |hash, job|
          hash.merge(job.args => job.result)
        end
      end
    end

private

    def mark_as_started
      update_attributes(:started_at => Time.now)
    end

    def mark_as_cancelled
      update_attributes(:cancelled_at => Time.now)
    end

    def mark_employee
      require 'socket'
      update_attributes(:employee_host    => Socket.gethostname,
                        :employee_pid     => Process.pid)
    end

    def mark_exception(exception)
      update_attributes(:status => 'error', :error_class => exception.class.to_s, :error_message => exception.message, :error_backtrace => exception.backtrace)
    end

    def mark_as_completed
      self.status ||= 'success'
      self.completed_at = Time.now
      self.save
    end

    class << self
      def call_path(path, *args)
        require 'active_support'
    
        raise ArgumentError, "Invalid path (must have #)" unless path.match(/.#./)
        controller, action = path.split('#')
    
        controller_object = begin
          Kernel.const_get("#{controller.classify}Jobs").new
        rescue NameError
          raise ArgumentError, "Invalid controller"
        end
    
        raise ArgumentError, "Invalid path action" unless controller_object.respond_to?(action)
    
        controller_object.send(action, *args)
      end
    
      def pending_paths
        self.pending.except(:order).select('DISTINCT path').collect(&:path)
      end
    end
  end
end