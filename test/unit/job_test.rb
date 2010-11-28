require 'test_helper'
require 'active_record'
require 'job_boss/boss'
require 'job_boss/job'
Dir.glob('test/app_root/app/jobs/*_jobs.rb').each {|lib| require lib }

class DaemonTest < ActiveSupport::TestCase
  test "job queuing" do
    start_daemon(:application_root => @app_root_path)

    wait_for_file(@log_path)

    config = YAML.load(File.read(@db_yaml_path))

    ActiveRecord::Base.establish_connection(config['development'])

    jobs = (0..10).collect do |i|
      JobBoss::Boss.queue.math.is_prime?(i)
    end

    JobBoss::Job.wait_for_jobs(jobs)

    assert_equal 11, JobBoss::Job.completed.count

    JobBoss::Job.result_hash(jobs).each do |args, result|
      assert_equal MathJobs.new.is_prime?(args.first), result
    end

    job = JobBoss::Boss.queue.string.concatenate('test', 'of', 'concatenation')
    JobBoss::Job.wait_for_jobs(job)
    assert_equal 12, JobBoss::Job.completed.count

    assert_equal 'testofconcatenation', job.result

    stop_daemon
  end
end
