require 'librato-sidekiq/configuration'

module Librato
  module Sidekiq
    class Middleware
      attr_reader :config

      def initialize(options = {})
        @config = options[:config]
      end

      # redis_pool is needed for the sidekiq 3 upgrade
      # https://github.com/mperham/sidekiq/blob/master/3.0-Upgrade.md
      def call(worker_instance, msg, queue, redis_pool = nil)
        start_time = Time.now
        result = yield
        elapsed = (Time.now - start_time).to_f

        return result unless config.enabled
        # puts "#{worker_instance} #{queue}"

        stats = ::Sidekiq::Stats.new

        Librato.group 'sidekiq' do |sidekiq|
          track sidekiq, stats, worker_instance, msg, queue, elapsed
        end

        result
      end

      private

      def track(tracking_group, stats, worker_instance, msg, queue, elapsed)
        submit_general_stats tracking_group, stats
        return unless config.allowed_to_submit queue, worker_instance
        # puts "doing Librato insert"
        tracking_group.group queue.to_s do |q|
          q.increment 'processed'
          q.timing 'time', elapsed
          q.measure 'enqueued', stats.queues[queue].to_i

          # using something like User.delay.send_email invokes
          # a class name with slashes. remove them in favor of underscores
          q.group msg['class'].underscore.gsub('/', '_') do |w|
            w.increment 'processed'
            w.timing 'time', elapsed
          end
        end
      end

      def submit_general_stats(group, stats)
        group.increment 'processed'
        {
          enqueued: nil,
          failed: nil,
          scheduled_size: 'scheduled'
        }.each do |method, name|
          group.measure((name || method).to_s, stats.send(method).to_i)
        end
      end
    end
  end
end
