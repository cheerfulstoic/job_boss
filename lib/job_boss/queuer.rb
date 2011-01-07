module JobBoss
  class Queuer
    def initialize(attributes = nil)
      @attributes = attributes || {}
    end
  
    def method_missing(method_id, *args)
      require 'active_support'
      require 'job_boss/job'

      method_name = method_id.id2name

      if @classes && @controller
        # In here, we've already figured out the class, so assume the method_missing call is to the method
        actionable_class = @classes.detect {|controller_class| controller_class.respond_to?(method_name) }

        if actionable_class
          require 'job_boss/job'
          path = "#{@controller}##{method_name}"

          @class = nil
          @controller = nil

          Job.create(@attributes.merge(:path => path,
                                        :args => args))
        else
          raise ArgumentError, "Invalid action"
        end
      else
        # Check to see if there's a class
        @classes = []
        begin
          @classes << Kernel.const_get("#{method_name.classify}Jobs").new
        rescue NameError
        end

        begin
          @classes << Kernel.const_get("#{method_name.classify}")
        rescue
        end

        raise ArgumentError, "Invalid controller" if @classes.blank?

        @controller = method_name

        self
      end
    end
  end
end