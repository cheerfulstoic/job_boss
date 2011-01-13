require 'active_support'

module JobBoss
  class Batch
    attr_accessor :batch_id

    extend ActiveSupport::Memoizable
    # Used to queue jobs in a batch
    # Usage:
    #   batch.queue.math.is_prime?(42)
    def queue
      require 'job_boss/queuer'
      Queuer.new(:batch_id => @batch_id)
    end
    memoize :queue

    # Used to queue jobs in a batch
    # Usage:
    #   batch.queue_path('math#in_prime?', 42)
    def queue_path(path, *args)
      controller, action = path.split('#')

      queue.send(controller).send(action, *args)
    end

    def initialize(batch_id = nil)
      @batch_id = batch_id || Batch.generate_batch_id
    end

    # Returns ActiveRecord::Relation representing query for jobs in batch
    def jobs
      Job.where('batch_id = ?', @batch_id)
    end

    # Allow calling of Job class methods from a batch which will be called
    # on in the scope of the jobs for the batch
    # Examples: wait_for_jobs, result_hash, time_taken, completed_percent
    def method_missing(sym, *args, &block)
      jobs.send(sym, *args, &block)
    end

  private
    class << self
      def generate_batch_id(size = 32)
        characters = (0..9).to_a + ('a'..'f').to_a

        (1..size).collect do |i|
          characters[rand(characters.size)]
        end.join
      end
    end
  end
end
