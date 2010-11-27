# job_boss

## Credits

The idea for this gem came from trying to use working/starling and not having much success with stability.  After some discussions with my colleagues (Neil Cook and Justin Hahn) and some good ideas, I created job_boss

## Purpose

job_boss allows you to have a daemon much in the same way as workling which allows you to process a series of jobs asynchronously.   job_boss, however, uses ActiveRecord to store queued job requests in a database thus simplifying dependencies.  This allows for us to process chunks of work in parallel, across multiple servers, without needing much setup

## Usage

Add the gem to your Gemfile

    gem 'job_boss'

or install it

    gem install job_boss

Create a directory to store classes which define code which can be executed by the job boss (the default directory is 'app/jobs') and create class files such as this:

    # app/jobs/math_jobs.rb
    class MathJobs
        def is_prime?(i)
            ('1' * i) !~ /^1?$|^(11+?)\1+$/
        end
    end

Start up your boss:

    job_boss start -- <options>

You can get command line options with the command:

    job_boss run -- -h

But since you don't want to do that right now, it looks something like this:

    Usage: job_boss [start|stop|restart|status|watch] [-- <options>]
        -r, --application-root PATH      Path for the application root upon which other paths depend (defaults to .)
        -d, --database-yaml PATH         Path for database YAML (defaults to <application-root>/config/database.yml)
        -l, --log-path PATH              Path for log file (defaults to <application-root>/log/job_boss.log)
        -j, --jobs-path PATH             Path to folder with job classes (defaults to <application-root>/app/jobs)
        -e, --environment ENV            Environment to use in database YAML file (defaults to 'development')
        -s, --sleep-interval INTERVAL    Number of seconds for the boss to sleep between checks of the queue (default 0.5)
        -c, --child-limit LIMIT          Maximum number of employees (default 4)

From your Rails code or in a console (this functionality should probably be encapsulated in the job_boss gem):

    require 'job_boss/boss'
    jobs = (0..1000).collect do |i|
        JobBoss::Boss.queue.math.is_prime?(i)
    end

    JobBoss::Job.wait_for_jobs(jobs) # Will sleep until the jobs are all complete

    JobBoss::Job.result_hash(jobs) # => {[0]=>"f", [1]=>"f", [2]=>true, [3]=>true, [4]=>"f", ... }
