require 'active_support/core_ext/class/attribute_accessors'

module Librato
  module Sidekiq
    class Middleware
      cattr_accessor :enabled do
        true
      end

      cattr_accessor :whitelist_queues, :blacklist_queues, :whitelist_classes, :blacklist_classes do
        []
      end

      def initialize(options = {})
        # hard dependency on one or the other being present
        rails = !!defined?(Librato::Rails)
        rack = !!defined?(Librato::Rack)
        fail 'librato-sidekiq depends on having one of librato-rails or librato-rack installed' unless rails || rack

        # librato-rails >= 0.10 changes behavior of reporting agent
        if File.basename($PROGRAM_NAME) == 'sidekiq' && rails && Librato::Rails::VERSION.split('.')[1].to_i >= 10 && ENV['LIBRATO_AUTORUN'].nil?
          puts 'NOTICE: --------------------------------------------------------------------'
          puts 'NOTICE: THE REPORTING AGENT HAS NOT STARTED, AND NO METRICS WILL BE SENT'
          puts 'NOTICE: librato-rails >= 0.10 requires LIBRATO_AUTORUN=1 in your environment'
          puts 'NOTICE: --------------------------------------------------------------------'
        end

        reconfigure
      end

      def self.configure
        yield(self) if block_given?
        new # will call reconfigure
      end

      def options
        {
          enabled: enabled,
          whitelist_queues: whitelist_queues,
          blacklist_queues: blacklist_queues,
          whitelist_classes: whitelist_classes,
          blacklist_classes: blacklist_classes
        }
      end

      def reconfigure
        # puts "Reconfiguring with: #{options}"
        ::Sidekiq.configure_server do |config|
          config.client_middleware do |chain|
            chain.remove ClientMiddleware
            chain.add ClientMiddleware, options
          end
          config.server_middleware do |chain|
            chain.remove self.class
            chain.add self.class, options
          end
        end
      end

      # redis_pool is needed for the sidekiq 3 upgrade
      # https://github.com/mperham/sidekiq/blob/master/3.0-Upgrade.md
      def call(worker_instance, msg, queue, redis_pool = nil)
        start_time = Time.now
        result = yield
        elapsed = (Time.now - start_time).to_f

        return result unless enabled
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
        return unless allowed_to_submit queue, worker_instance
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

      def queue_in_whitelist(queue)
        whitelist_queues.nil? || whitelist_queues.empty? || whitelist_queues.include?(queue.to_s)
      end

      def queue_in_blacklist(queue)
        blacklist_queues.include?(queue.to_s)
      end

      def class_in_whitelist(worker_instance)
        whitelist_classes.nil? || whitelist_classes.empty? || whitelist_classes.include?(worker_instance.class.to_s)
      end

      def class_in_blacklist(worker_instance)
        blacklist_classes.include?(worker_instance.class.to_s)
      end

      def allowed_to_submit(queue, worker_instance)
        class_in_whitelist(worker_instance) && !class_in_blacklist(worker_instance) && queue_in_whitelist(queue) && !queue_in_blacklist(queue)
      end
    end
  end
end
