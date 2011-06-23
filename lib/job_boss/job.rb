
module JobBoss
  class Job < ActiveRecord::Base
    default_scope order('created_at')

    serialize :args
    serialize :result
    serialize :error_backtrace

    scope :pending, where('started_at IS NULL AND cancelled_at IS NULL')
    scope :running, where('started_at IS NOT NULL AND completed_at IS NULL')
    scope :completed, where('completed_at IS NOT NULL')
    scope :not_completed, where('completed_at IS NOT NULL')
    scope :unfinished, where('completed_at IS NULL AND cancelled_at IS NULL')
    scope :mia, where("completed_at IS NOT NULL AND status = 'mia'")

    def prototype
      self.path + "(#{self.args.collect(&:inspect).join(', ')})"
    end

    # Method used by the boss to dispatch an employee
    def dispatch(boss)
      if mark_as_started
        boss.logger.info "Dispatching Job ##{self.id}: #{self.prototype}"

        pid = fork do
          ActiveRecord::Base.connection.reconnect!
          $0 = "[job_boss employee] job ##{self.id} #{self.prototype})"
          Process.setpriority(Process::PRIO_PROCESS, 0, 19)

          begin
            mark_employee

            value = self.class.call_path(self.path, *self.args)

            self.update_attribute(:result, value)
          rescue Exception => exception
            mark_exception(exception)
            boss.logger.error "Error running job ##{self.id}!"
          ensure
            until mark_as_completed
              sleep(1)
            end

            boss.logger.info "Job ##{self.id} completed in #{self.time_taken} seconds, exiting..."
            Kernel.exit
          end
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

    def batch
      self.batch_id && Batch.new(:batch_id => self.batch_id, :priority => self.priority)
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
      self.cancelled_at = nil
      self.status = nil
      self.error_class = nil
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

    def mark_as_mia
      self.completed_at = Time.now
      self.status = 'mia'
      self.save
    end

    def mia?
      completed_at && (status == 'mia')
    end

    # Has the job been assigned to an employee?
    def assigned?
      # If the #assigned? method is being called for but the job hasn't been completed, reload
      # to check to see if it has been assigned
      self.reload if !completed? && employee_pid.nil?

      employee_pid && employee_host
    end

    # Is the job running?
    def running?
      # If the #running? method is being called for but the job hasn't started, reload
      # to check to see if it has been assigned
      self.reload if started_at.nil? || completed_at.nil?

      started_at && !completed_at
    end

    # How long did the job take?
    def time_taken
      # If the #time_taken method is being called for but the job doesn't seem to have started/completed
      # reload to see if it has
      self.reload if started_at.nil? || completed_at.nil?

      completed_at - started_at if completed_at && started_at
    end

    # How long did have set of jobs taken?
    # Returns nil if not all jobs are complete
    def self.time_taken
      return nil if self.completed.count != self.count

      self.maximum(:completed_at) - self.minimum(:started_at)
    end

    # Returns the completion percentage of a set of jobs
    def self.completed_percent
      self.completed.count.to_f / self.count.to_f
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
      # Given a job or an array of jobs
      # Will cause the process to sleep until all specified jobs have completed
      # sleep_interval specifies polling period
      def wait_for_jobs(jobs = nil, sleep_interval = 0.5)
        at_exit do
          Job.not_completed.find(jobs).each(&:cancel)
        end

        jobs = get_jobs(jobs)

        ids = jobs.collect(&:id)
        Job.uncached do
          until Job.unfinished.find_all_by_id(ids).count == 0
            sleep(sleep_interval)

            if block_given?
              yield((Job.where('id in (?)', ids).completed.count.to_f / jobs.size.to_f) * 100.0)
            end
          end
        end

        true
      end

      # Given a job or an array of jobs
      # Returns a hash where the keys are the job method arguments and the values are the
      # results of the job processing
      def result_hash(jobs = nil)
        jobs = get_jobs(jobs)

        # the #result method automatically reloads the result here if needed but this will
        # do it in one SQL call
        jobs = Job.find(jobs.collect(&:id))

        require 'yaml'
        jobs.inject({}) do |hash, job|
          hash.merge(job.args => job.result)
        end
      end

      def cancelled?
        count = self.where('cancelled_at IS NULL').count

        !(count > 0)
      end

      def cancel(jobs = nil)
        jobs = get_jobs(jobs)

        self.all.each(&:cancel)
      end

      def get_jobs(jobs)
        jobs = [jobs] if jobs.is_a?(Job)
        jobs = self.scoped if jobs.nil?
        jobs
      end

      # Given a time object
      # Delete all jobs which were completed earlier than that time
      def delete_jobs_before(time)
        completed.where('completed_at < ?', time).delete_all
      end
    end

private

    def mark_as_started
      Job.update_all(['started_at = ?', Time.now], ['started_at IS NULL AND id = ?', job]) > 0
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
    
        controller_objects = []
        begin
          controller_objects << Kernel.const_get("#{controller.classify}Jobs").new
        rescue NameError
        end

        begin
          controller_objects << Kernel.const_get("#{controller.classify}")
        rescue NameError
        end

        raise ArgumentError, "Invalid controller: #{controller}" if controller_objects.empty?

        controller_object = controller_objects.detect {|controller_object| controller_object.respond_to?(action) }

        raise ArgumentError, "Invalid path action: #{action}" if !controller_object

        controller_object.send(action, *args)
      end
    end
  end
end