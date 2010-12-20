class Sleep < ActiveRecord::Base
  class << self
    def add_snoozes(i,j)
      i + j
    end
  end
end