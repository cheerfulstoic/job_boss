module JobBoss
  class Queuer
    def method_missing(method_id, *args)
      require 'active_support'
      require 'job_boss/job'

      method_name = method_id.id2name

      if @class && @controller
        # In here, we've already figured out the class, so assume the method_missing call is to the method

        if @class.respond_to?(method_name)
          require 'job_boss/job'
          path = "#{@controller}##{method_name}"

          @class = nil
          @controller = nil

          Job.create(:path => path,
                     :args => args)
        else
          raise ArgumentError, "Invalid action"
        end
      else
        # Check to see if there's a class
        begin
          # If we find a class that ends in "Jobs", we instanciate it and call an instance method
          @class = Kernel.const_get("#{method_name.classify}Jobs").new

          @controller = method_name
        rescue NameError
          begin
            # If we don't find a class that ends in "Jobs", we're going to call a class method
            @class = Kernel.const_get("#{method_name.classify}")

            @controller = method_name
          rescue
            raise ArgumentError, "Invalid controller"
          end
        end

        self
      end
    end
  end
end