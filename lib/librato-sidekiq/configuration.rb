require 'active_support/core_ext/class/attribute_accessors'

module Librato
  module Sidekiq
    class Configuration
      ARRAY_OPTIONS = [:whitelist_queues, :blacklist_queues, :whitelist_classes, :blacklist_classes]
      OPTIONS = [:enabled] + ARRAY_OPTIONS

      attr_accessor :enabled, *ARRAY_OPTIONS

      def initialize()
        self.enabled = true
        ARRAY_OPTIONS.each {|o| self.send("#{o}=", [])}
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