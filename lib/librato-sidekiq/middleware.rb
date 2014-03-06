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
        raise "librato-sidekiq depends on having one of librato-rails or librato-rack installed" unless rails || rack

        # librato-rails >= 0.10 changes behavior of reporting agent
        if File.basename($0) == 'sidekiq' && rails && Librato::Rails::VERSION.split('.')[1].to_i >= 10 && ENV['LIBRATO_AUTORUN'].nil?
          puts "NOTICE: --------------------------------------------------------------------"
          puts "NOTICE: THE REPORTING AGENT HAS NOT STARTED, AND NO METRICS WILL BE SENT"
          puts "NOTICE: librato-rails >= 0.10 requires LIBRATO_AUTORUN=1 in your environment"
          puts "NOTICE: --------------------------------------------------------------------"
        end

        self.reconfigure
      end

      def self.configure
        yield(self) if block_given?
        self.new # will call reconfigure
      end

      def options
        {
          :enabled => self.enabled,
          :whitelist_queues => self.whitelist_queues, 
          :blacklist_queues => self.blacklist_queues, 
          :whitelist_classes => self.whitelist_classes, 
          :blacklist_classes => self.blacklist_classes
        }
      end

      def reconfigure
        # puts "Reconfiguring with: #{options}"
        ::Sidekiq.configure_server do |config|
          config.server_middleware do |chain|
            chain.remove self.class
            chain.add self.class, self.options
          end
        end
      end

      def call(worker_instance, msg, queue)
        unless self.enabled
          # puts "Gem not enabled"
          yield
          return
        end

        t = Time.now
        yield
        elapsed = (Time.now - t).to_f

        queue_in_whitelist = self.whitelist_queues.nil? || self.whitelist_queues.empty? || self.whitelist_queues.include?(queue.to_s)
        queue_in_blacklist = self.blacklist_queues.include?(queue.to_s)
        class_in_whitelist = self.whitelist_classes.nil? || self.whitelist_classes.empty? || self.whitelist_classes.include?(worker_instance.class.to_s)
        class_in_blacklist = self.blacklist_classes.include?(worker_instance.class.to_s)

        # puts "#{worker_instance} #{queue} qw:#{queue_in_whitelist} qb:#{queue_in_blacklist} cw:#{class_in_whitelist} cb:#{class_in_blacklist}"

        Librato.group 'sidekiq' do |sidekiq|
          stats = ::Sidekiq::Stats.new

          sidekiq.increment 'processed'

          {
            enqueued: nil,
            failed: nil,
            scheduled_size: 'scheduled'
          }.each do |method, name|
            sidekiq.measure (name || method).to_s, stats.send(method).to_i
          end

          return unless class_in_whitelist && !class_in_blacklist && queue_in_whitelist && !queue_in_blacklist
          # puts "doing Librato insert"

          sidekiq.group queue.to_s do |q|
            q.increment 'processed'
            q.timing 'time', elapsed
            q.measure 'enqueued', stats.queues[queue].to_i

            # using something like User.delay.send_email invokes a class name with slashes
            # remove them in favor of underscores
            q.group msg["class"].underscore.gsub('/', '_') do |w|
              w.increment 'processed'
              w.timing 'time', elapsed
            end
          end
        end
      end
    end
  end
end
