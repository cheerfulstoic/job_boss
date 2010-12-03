require 'job_boss/job'
require 'job_boss/boss'

module JobBoss
  autoload :Boss, 'job_boss/boss'
  autoload :Job, 'job_boss/job'
end

include JobBoss