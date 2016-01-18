require 'librato-sidekiq/configuration'

module Librato
  module Sidekiq
    class ClientMiddleware < Middleware
      protected

      def track(tracking_group, stats, worker_instance, msg, queue, elapsed)
        tracking_group.increment 'queued'
        return unless config.allowed_to_submit queue, worker_instance
        # puts "doing Librato insert"
        tracking_group.group queue.to_s do |q|
          q.increment 'queued'

          # using something like User.delay.send_email invokes
          # a class name with slashes. remove them in favor of underscores
          q.group msg['class'].underscore.gsub('/', '_') do |w|
            w.increment 'queued'
          end
        end
      end
    end
  end
end
