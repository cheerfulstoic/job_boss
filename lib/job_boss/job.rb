
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
      require 'spawn'

      spawn(:nice => 19) do
        begin
          $0 = "job_employee (job ##{self.id})"

          Signal.trap("HUP") do
            self.mark_for_redo
          end

          result = self.class.call_path(self.path, *self.args)
          self.update_attribute(:result, result)
        rescue Exception => exception
          self.mark_exception(exception)
        ensure
          self.mark_as_completed
          Kernel.exit
        end
      end
    end

    def mark_as_started
      require 'socket'
      update_attributes(:started_at       => Time.now,
                        :employee_host    => Socket.gethostname,
                        :employee_pid     => Process.pid)
    end

    def mark_exception(exception)
      update_attributes(:status => :error, :error_message => exception.message, :error_backtrace => exception.backtrace)
    end

    def mark_as_completed
      self.status ||= :success
      self.completed_at = Time.now
      self.save
    end

    def mark_for_redo
      update_attributes(:started_at => nil, :completed_at => nil, :status => nil, :error_message => nil, :error_backtrace => nil)
    end

    def completed?
      !!completed_at
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