require 'active_record'
require 'job_boss/job'

class JobBoss

  def initialize(options = {})
    @sleep_interval = (options[:sleep_interval] || 0.5).to_f
    @child_limit = (options[:child_limit] || 4).to_i
    @running_jobs = []
  end

  def cleanup_running_jobs
    Job.uncached do
      @running_jobs = Job.running.where('id in (?)', @running_jobs)
    end
  end

  def available_children
    cleanup_running_jobs

    @child_limit - @running_jobs.size
  end

  def start
    Signal.trap("HUP") do
      self.stop
    end

    at_exit { self.stop }

    puts "Job Boss started"

    while true
      unless (children_count = available_children) > 0 && Job.pending.count > 0
        sleep(@sleep_interval)
        next
      end

      Job.pending_paths.each do |path|
        job = Job.pending.find_by_path(path)
        next if job.nil?

        job.dispatch
        @running_jobs << job

        children_count -= 1
        break unless children_count > 0
      end

    end
  end

  def stop
    puts "Job Boss stopped"
  end
end
