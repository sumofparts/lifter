require 'zlib'

module Lifter
  class ThreadPool
    def initialize(pool_size)
      @pool_size = pool_size

      @monitor = Monitor.new

      @queues = {}
      @workers = {}

      @pending = {}
      @cleared = []

      spawn_workers
    end

    # Add a job closure to the thread pool, tagged with a given job_tag to allow for consistent
    # execution ordering.
    def push(job_tag, &job)
      job_tag = job_tag.to_s

      raise ArgumentError.new('job_tag must be defined') if job_tag.empty?

      job_hash = Zlib.crc32(job_tag)
      worker_id = job_hash % @pool_size

      queue = @queues[worker_id]
      queue.push([job_tag, job])

      add_pending(job_tag)
    end

    # For a given job_tag, prevents any future pending jobs from running.
    def clear(job_tag)
      @monitor.synchronize do
        @cleared << job_tag if !@cleared.include?(job_tag)
      end
    end

    private def cleared?(job_tag)
      cleared = false

      @monitor.synchronize do
        cleared = @cleared.include?(job_tag)
        @cleared.delete(job_tag) if count_pending(job_tag) == 0
      end

      cleared
    end

    private def add_pending(job_tag)
      @monitor.synchronize do
        count = count_pending(job_tag)
        @pending[job_tag] = count + 1
      end
    end

    private def count_pending(job_tag)
      count = 0

      @monitor.synchronize do
        count = @pending[job_tag] || 0
      end

      count
    end

    private def remove_pending(job_tag)
      @monitor.synchronize do
        count = count_pending(job_tag)

        if count == 0
          @pending.delete(job_tag)
        else
          @pending[job_tag] = count - 1
        end
      end
    end

    private def spawn_workers
      (0...@pool_size).each do |worker_id|
        queue = Queue.new

        @queues[worker_id] = queue

        worker = Thread.new do
          loop do
            job_tag, job = queue.pop
            remove_pending(job_tag)

            next if cleared?(job_tag)

            begin
              job.call
            rescue StandardError => e
              puts e.to_s
              puts e.backtrace
              exit
              add_pending(job_tag)
              queue.push([job_tag, job])
            end
          end
        end

        @workers[worker_id] = worker
      end
    end
  end
end
