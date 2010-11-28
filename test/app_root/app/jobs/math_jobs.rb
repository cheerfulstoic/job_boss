class MathJobs
    def is_prime?(i)
        ('1' * i) !~ /^1?$|^(11+?)\1+$/
    end
end
