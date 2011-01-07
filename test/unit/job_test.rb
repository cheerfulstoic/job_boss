require 'test_helper'
require 'active_record'
require 'job_boss'

Dir.chdir('test/app_root')

Dir.glob('app/jobs/*_jobs.rb').each {|lib| require lib }
Dir.glob('app/models/*.rb').each {|lib| require lib }

class DaemonTest < ActiveSupport::TestCase
  test "job queuing" do
    start_daemon(:application_root => @app_root_path)

    wait_for_file(@log_path)

    config = YAML.load(File.read(@db_yaml_path))

    ActiveRecord::Base.establish_connection(config['development'])

    # Test returning results from a number of jobs
    jobs = (0..10).collect do |i|
      Boss.queue.math.is_prime?(i)
    end

    Job.wait_for_jobs(jobs)

    assert_equal 11, Job.completed.count

    Job.result_hash(jobs).each do |args, result|
      assert_equal MathJobs.new.is_prime?(args.first), result
    end


    # Test functions with multiple arguments and a complex return value (an Array in this case)
    job = Boss.queue.string.concatenate('test', 'of', 'concatenation')
    Job.wait_for_jobs(job)
    assert_equal 12, Job.completed.count

    assert_equal ['testofconcatenation', 3], job.result

    assert job.time_taken > 0
    assert_nil job.error


    job = Boss.queue.penguin.snooze(3)
    time = Benchmark.realtime do
      Job.wait_for_jobs(job)
    end

    assert_equal 13, Job.completed.count

    assert job.time_taken > 3
    assert_equal 'ZzZzZzzz', job.result

    # Test `queue_path` method
    job = Boss.queue_path('string#concatenate', 'test', 'of', 'concatenation')
    Job.wait_for_jobs(job)
    assert_equal 14, Job.completed.count

    assert_equal ['testofconcatenation', 3], job.result

    # Test cancelling of a job
    job = Boss.queue.sleep.sleep_for(10)

    wait_until_job_assigned(job)

    assert_pid_running(job.employee_pid)

    job.cancel

    sleep(2)

    assert_pid_not_running(job.employee_pid)

    job.reload
    assert job.cancelled?
    assert_not_nil job.cancelled_at


    # Test recording of MIA jobs
    job = Boss.queue.sleep.sleep_for(20)

    wait_until_job_assigned(job)

    assert_pid_running(job.employee_pid)

    Process.kill(9, job.employee_pid)

    sleep(1)

    assert_pid_not_running(job.employee_pid)

    job.reload
    assert job.mia?
    assert_equal [job.id], Job.mia.collect(&:id)

    jobs = (0..10).collect do |i|
      job = Boss.queue.sleep.sleep_for(1)
    end

    progresses = []
    Job.wait_for_jobs(jobs) do |progress|
#      puts progress
      progresses << progress
    end

    assert_equal progresses, progresses.sort
    assert progresses.all? {|progress| 0.0 <= progress && progress <= 100.0 }
    assert progresses.any? {|progress| progress > 1.0 }

    # Test deleting of old jobs

    # Sleep for 1 second so that the upcoming deletions work correctly
    sleep(1)

    Job.delete_jobs_before(20.seconds.ago)
    assert Job.completed.count > 0
    Job.delete_jobs_before(1.second.ago)
    assert_equal 0, Job.completed.count

    # Test raising of errors
    job = Boss.queue.sleep.do_not_never_sleep
    Job.wait_for_jobs(job)
    job.reload

    error = job.error
    assert_equal ArgumentError, error.class
    assert_equal "I can't not do that, Dave.", error.message
    assert_equal Array, error.backtrace.class



    # Test calling method where there is both a Sleep model and a SleepJobs class
    job = Boss.queue.sleep.add_snoozes(2, 5)

    Job.wait_for_jobs(job)

    assert_equal 7, job.result


    # Test Batch class
    batch = Batch.new

    jobs = (0..10).collect do |i|
      batch.queue.math.is_prime?(i)
    end

    batch.wait_for_jobs

    batch.result_hash.each do |args, result|
      assert_equal MathJobs.new.is_prime?(args.first), result
    end


    # Test to make sure that different batches run in parallel where non-batched jobs don't

    batch1 = Batch.new

    first_jobs = (0..3).collect do
      batch1.queue.sleep.sleep_for(3)
    end

    batch2 = Batch.new
    job2 = batch2.queue.sleep.sleep_for(3)

    sleep(1)

    assert first_jobs[0,3].all? {|job| job.running? }
    assert !first_jobs.last.running?
    assert job2.running?

    sleep(3)

    assert first_jobs[0,3].all? {|job| !job.running? }
    assert first_jobs.last.running?
    assert !job2.running?

    sleep(3)

    assert !first_jobs.last.running?


    first_jobs = (0..3).collect do
      Boss.queue.sleep.sleep_for(3)
    end
    job2 = Boss.queue.sleep.sleep_for(3)

    sleep(1)

    assert first_jobs.all? {|job| job.running? }
    assert !job2.running?
    sleep(3)
    assert first_jobs.all? {|job| !job.running? }
    assert job2.running?
    sleep(3)
    assert first_jobs.all? {|job| !job.running? }
    assert !job2.running?

    stop_daemon
  end
end
