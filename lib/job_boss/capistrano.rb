# Capistrano task for job_boss.
#
# Just add "require 'job_boss/capistrano'" in your Capistrano deploy.rb, and
# job_boss will be activated after each new deployment.

Capistrano::Configuration.instance(:must_exist).load do
  after "deploy:update_code", "job_boss:restart"
end
