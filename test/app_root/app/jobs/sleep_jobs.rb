class SleepJobs
  def sleep_for(time)
    sleep(time)
  end

  def do_not_never_sleep
    raise ArgumentError, "I can't not do that, Dave."
  end
end