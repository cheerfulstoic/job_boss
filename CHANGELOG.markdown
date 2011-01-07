## 0.6.5

* Ability to create jobs in batches.  Batches allow for better management of jobs.  Batches for the same task will also run in parallel as opposed to serially

## 0.6.0

* Concept of MIA jobs (boss process marks jobs as MIA when they are killed or otherwise die unhandled)
* Job.wait_for_jobs method takes a block which allows updating of progress percentage
* Output in jobs for MIA and cancelled jobs
