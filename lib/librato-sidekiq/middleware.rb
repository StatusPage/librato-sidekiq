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

          [:enqueued, :failed].each do |m|
            sidekiq.measure m.to_s, stats.send(m)
          end

          return unless class_in_whitelist && !class_in_blacklist && queue_in_whitelist && !queue_in_blacklist
          # puts "doing Librato insert"

          sidekiq.group queue.to_s do |q|
            q.increment 'processed'
            q.timing 'time', elapsed
            q.measure 'enqueued', stats.queues[queue]

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
