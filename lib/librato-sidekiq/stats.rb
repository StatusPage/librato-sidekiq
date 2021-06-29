# https://github.com/mperham/sidekiq/blob/v6.2.1/lib/sidekiq/api.rb#L8-L147
require 'sidekiq'

module Librato
  module Sidekiq
    class Stats
      def initialize
        fetch_stats!
      end

      def processed
        stat :processed
      end

      def failed
        stat :failed
      end

      def scheduled_size
        stat :scheduled_size
      end

      def retry_size
        stat :retry_size
      end

      def dead_size
        stat :dead_size
      end

      def enqueued
        stat :enqueued
      end

      def processes_size
        stat :processes_size
      end

      def default_queue_latency
        stat :default_queue_latency
      end

      def queues
        ::Sidekiq::Stats::Queues.new.lengths
      end

      def fetch_stats!
        pipe1_res = ::Sidekiq.redis { |conn|
          conn.pipelined do
            conn.get("stat:processed")
            conn.get("stat:failed")
            conn.zcard("schedule")
            conn.zcard("retry")
            conn.zcard("dead")
            conn.scard("processes")
            conn.lrange("queue:default", -1, -1)
          end
        }

        queues = ::Sidekiq.redis { |conn|
          conn.sscan_each("queues").to_a
        }

        pipe2_res = ::Sidekiq.redis { |conn|
          conn.pipelined do
            queues.each { |queue| conn.llen("queue:#{queue}") }
          end
        }

        enqueued = pipe2_res.sum(&:to_i)

        default_queue_latency = if (entry = pipe1_res[6].first)
                                  job = begin
                                          ::Sidekiq.load_json(entry)
                                        rescue
                                          {}
                                        end
                                  now = Time.now.to_f
                                  thence = job["enqueued_at"] || now
                                  now - thence
                                else
                                  0
                                end
        @stats = {
          processed: pipe1_res[0].to_i,
          failed: pipe1_res[1].to_i,
          scheduled_size: pipe1_res[2],
          retry_size: pipe1_res[3],
          dead_size: pipe1_res[4],
          processes_size: pipe1_res[5],

          default_queue_latency: default_queue_latency,
          enqueued: enqueued
        }
      end

      def reset(*stats)
        all = %w[failed processed]
        stats = stats.empty? ? all : all & stats.flatten.compact.map(&:to_s)

        mset_args = []
        stats.each do |stat|
          mset_args << "stat:#{stat}"
          mset_args << 0
        end
        ::Sidekiq.redis do |conn|
          conn.mset(*mset_args)
        end
      end

      private

      def stat(s)
        @stats[s]
      end
    end
  end
end
