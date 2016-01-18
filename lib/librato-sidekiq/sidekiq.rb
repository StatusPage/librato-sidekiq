module Librato
  module Sidekiq
    def self.config
      @config ||= Librato::Sidekiq::Configuration.new
    end

    def self.configure
      yield self.config if block_given?
      self.register
    end

    def self.reset
      @config = nil
      self.register
    end

    def self.register
      self.check_dependencies

      # puts "Reconfiguring with: #{options}"
      ::Sidekiq.configure_server do |config|
        config.server_middleware do |chain|
          chain.remove Librato::Sidekiq::Middleware
          chain.add Librato::Sidekiq::Middleware, config: self.config
        end
      end

      # puts "Reconfiguring with: #{options}"
      ::Sidekiq.configure_client do |config|
        config.client_middleware do |chain|
          chain.remove Librato::Sidekiq::ClientMiddleware
          chain.add Librato::Sidekiq::ClientMiddleware, config: self.config
        end
      end
    end

    # this is so we can stub it in the specs
    def self.program_name
      $PROGRAM_NAME
    end

    def self.check_librato_rails_version
      parts = Librato::Rails::VERSION.split('.')
      parts[0].to_i > 0 || parts[1].to_i >= 10
    end

    def self.check_dependencies
      # hard dependency on one or the other being present
      rails = !!defined?(Librato::Rails)
      rack = !!defined?(Librato::Rack)
      fail 'librato-sidekiq depends on having one of librato-rails or librato-rack installed' unless rails || rack

      # librato-rails >= 0.10 changes behavior of reporting agent
      if rails && File.basename(self.program_name) == 'sidekiq' && self.check_librato_rails_version && ENV['LIBRATO_AUTORUN'].nil?
        puts 'NOTICE: --------------------------------------------------------------------'
        puts 'NOTICE: THE REPORTING AGENT HAS NOT STARTED, AND NO METRICS WILL BE SENT'
        puts 'NOTICE: librato-rails >= 0.10 requires LIBRATO_AUTORUN=1 in your environment'
        puts 'NOTICE: --------------------------------------------------------------------'
      end
    end
  end
end