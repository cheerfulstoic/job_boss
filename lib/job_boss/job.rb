
module JobBoss
  class Job < ActiveRecord::Base
    default_scope order('created_at')

    serialize :args
    serialize :result
    serialize :error_backtrace

    scope :pending, where('started_at IS NULL')
    scope :running, where('started_at IS NOT NULL AND completed_at IS NULL')
    scope :completed, where('completed_at IS NOT NULL')

    # Method used by the boss to dispatch an employee
    def dispatch
      mark_as_started
      puts "Dispatching Job ##{self.id}"

      pid = fork do
        $0 = "job_boss - employee (job ##{self.id})"
        Process.setpriority(Process::PRIO_PROCESS, 0, 19)

        begin
          mark_employee

          Signal.trap("HUP") do
            mark_for_redo
          end

          result = self.class.call_path(self.path, *self.args)
          self.update_attribute(:result, result)
        rescue Exception => exception
          mark_exception(exception)
          puts "Error running job ##{self.id}!"
        ensure
          until mark_as_completed
            sleep(1)
          end

          puts "Job ##{self.id} completed, exiting..."
          Kernel.exit
        end
      end

      Process.detach(pid)
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

    # How long did the job take?
    def time_taken
      completed_at - started_at if completed_at && started_at
    end

    class << self
      def wait_for_jobs(jobs, sleep_interval = 0.5)
        running_jobs = jobs.dup

        until Job.running.find_all_by_id(running_jobs.collect(&:id)).empty?
          sleep(sleep_interval)
        end

        true
      end

      def result_hash(jobs)
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
      update_attributes(:status => 'error', :error_message => exception.message, :error_backtrace => exception.backtrace)
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