require 'job_boss/job'
require 'job_boss/boss'
require 'job_boss/batch'

module JobBoss
  autoload :Boss, 'job_boss/boss'
  autoload :Job, 'job_boss/job'
  autoload :Batch, 'job_boss/batch'
end

include JobBoss
