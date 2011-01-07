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

    def initialize(batch_id = nil)
      @batch_id = batch_id || Batch.generate_batch_id
    end

    # Returns ActiveRecord::Relation representing query for jobs in batch
    def jobs
      Job.where('batch_id = ?', @batch_id)
    end

    # Sleeps until jobs in batch are complete
    def wait_for_jobs
      Job.wait_for_jobs(jobs)
    end

    # Returns a hash with arguments as keys and results as values for jobs in batch
    def result_hash
      Job.result_hash(jobs)
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
