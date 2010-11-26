
module JobBoss
  class Job < ActiveRecord::Base
    default_scope order('created_at')

    serialize :args
    serialize :result
    serialize :error_backtrace

    scope :pending, where('started_at IS NULL')
    scope :running, where('started_at IS NOT NULL AND completed_at IS NULL')
    scope :completed, where('completed_at IS NOT NULL')

    def dispatch
      self.mark_as_started
      puts "Dispatching Job ##{self.id}"

      fork do
        self.mark_employee
        Process.setpriority(Process::PRIO_PROCESS, 0, 19)

        begin
          $0 = "job_employee (job ##{self.id})"

          Signal.trap("HUP") do
            self.mark_for_redo
          end

          result = self.class.call_path(self.path, *self.args)
          self.update_attribute(:result, result)
        rescue Exception => exception
          self.mark_exception(exception)
          puts "Error running job ##{self.id}!"
        ensure
          self.mark_as_completed
          puts "Job ##{self.id} completed, exiting..."
          Kernel.exit
        end
      end
    end

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

    def completed?
      !!completed_at
    end

    def succeeded?
      completed_at && (status == 'success')
    end

    def time_taken
      completed_at - started_at if completed_at && started_at
    end

private

    def mark_as_started
      update_attributes(:started_at       => Time.now)
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
end