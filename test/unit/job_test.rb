require 'test_helper'
require 'active_record'
require 'job_boss/boss'
require 'job_boss/job'

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
      JobBoss::Boss.queue.math.is_prime?(i)
    end

    JobBoss::Job.wait_for_jobs(jobs)

    assert_equal 11, JobBoss::Job.completed.count

    JobBoss::Job.result_hash(jobs).each do |args, result|
      assert_equal MathJobs.new.is_prime?(args.first), result
    end


    # Test functions with multiple arguments and a complex return value (an Array in this case)
    job = JobBoss::Boss.queue.string.concatenate('test', 'of', 'concatenation')
    JobBoss::Job.wait_for_jobs(job)
    assert_equal 12, JobBoss::Job.completed.count

    assert_equal ['testofconcatenation', 3], job.result

    assert job.time_taken > 0
    assert_nil job.error


    job = JobBoss::Boss.queue.penguin.snooze(3)
    time = Benchmark.realtime do
      JobBoss::Job.wait_for_jobs(job)
    end

    assert_equal 13, JobBoss::Job.completed.count

    assert job.time_taken > 3
    assert_equal 'ZzZzZzzz', job.result

    # Test `queue_path` method
    job = JobBoss::Boss.queue_path('string#concatenate', 'test', 'of', 'concatenation')
    JobBoss::Job.wait_for_jobs(job)
    assert_equal 14, JobBoss::Job.completed.count

    assert_equal ['testofconcatenation', 3], job.result

    # Test cancelling of a job
    job = JobBoss::Boss.queue.sleep.sleep_for(10)

    wait_until_job_assigned(job)

    assert_pid_running(job.employee_pid)

    job.cancel

    sleep(2)

    assert_pid_not_running(job.employee_pid)

    job.reload
    assert job.cancelled?
    assert_not_nil job.cancelled_at



    # Test raising of errors
    job = JobBoss::Boss.queue.sleep.do_not_never_sleep
    JobBoss::Job.wait_for_jobs(job)
    job.reload

    error = job.error
    assert_equal ArgumentError, error.class
    assert_equal "I can't not do that, Dave.", error.message
    assert_equal Array, error.backtrace.class

    stop_daemon
  end
end
