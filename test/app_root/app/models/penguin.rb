class Penguin < ActiveRecord::Base
  class << self
    def snooze(time)
      sleep(time)

      "ZzZzZzzz"
    end
  end
end