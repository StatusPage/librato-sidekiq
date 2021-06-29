module Librato
  module Sidekiq
    class ClientMiddleware < Middleware
      def self.reconfigure
        client_configuration = Proc.new do |config|
          config.client_middleware do |chain|
            chain.remove self
            chain.add self, options
          end
        end
        # puts "Reconfiguring with: #{options}"
        ::Sidekiq.configure_client(&client_configuration)
        # Add to the client used on the server too (so jobs enqueued by other jobs get metrics, not just those enqueued by the app)
        ::Sidekiq.configure_server(&client_configuration)
      end

      protected

      def track(tracking_group, _stats, worker_instance, msg, queue, _elapsed, _latency)
        tracking_group.increment 'queued'
        return unless allowed_to_submit queue, worker_instance

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
