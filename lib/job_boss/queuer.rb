module JobBoss
  class Queuer
    def method_missing(method_id, *args)
      require 'active_support'

      method_name = method_id.id2name

      if @class && @controller
        # In here, we've already figured out the class, so assume the method_missing call is to the method

        if @class.respond_to?(method_name)
          Job.create(:path => "#{@controller}##{method_name}",
                      :args => args)
        else
          raise ArgumentError, _("Invalid action")
        end
      else
        # Check to see if there's a jobs class
        @class = begin
          Kernel.const_get("#{method_name.classify}Jobs").new

          @controller = method_name
        rescue NameError
          raise ArgumentError, _("Invalid controller")
        end

        self
      end
    end
  end
end