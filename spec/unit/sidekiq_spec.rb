require 'spec_helper'

describe Librato::Sidekiq do
  describe '::config' do
    it 'should return a Configuration object' do
      expect(described_class.config).to be_an_instance_of(Librato::Sidekiq::Configuration)
    end
  end

  describe '::configure' do
    before do
      allow(described_class).to receive(:register)
    end
    it 'should yield to the passed block' do
      expect { |b| described_class.configure(&b) }.to yield_control
    end

    it 'should yield the configuration object' do
      expect { |b| described_class.configure(&b) }.to yield_with_args(described_class.config)
    end
  end

  describe '::reset' do
    before do
      allow(described_class).to receive(:register)
    end
    it 'should clear the config' do
      described_class.config # Prime it
      expect {
        described_class.reset
      }.to change { described_class.instance_variable_get(:@config) }.to(nil)
    end

    it 'should call the register command' do
      expect(described_class).to receive(:register)

      described_class.reset
    end
  end

  describe '::register' do
    let(:sidekiq) { double('Sidekiq', configure_server: true, configure_client: true)}
    before do
      stub_const 'Sidekiq', sidekiq
      allow(described_class).to receive(:check_dependencies)
    end

    it 'should call check_dependencies' do
      expect(described_class).to receive(:check_dependencies)

      described_class.register
    end

    it 'should call configure_server' do
      expect(sidekiq).to receive(:configure_server).once

      described_class.register
    end

    it 'should call configure_client' do
      expect(sidekiq).to receive(:configure_client).once

      described_class.register
    end

    context 'checking sidekiq registration' do
      it 'should add itself to the server middleware chain' do
        chain = double()
        config = double()
        expect(chain).to receive(:remove).with Librato::Sidekiq::Middleware
        expect(chain).to receive(:add).with Librato::Sidekiq::Middleware, config: described_class.config

        expect(config).to receive(:server_middleware).once.and_yield(chain)
        expect(Sidekiq).to receive(:configure_server).once.and_yield(config)

        described_class.register
      end

      it 'should add itself to the client middleware chain' do
        chain = double()
        config = double()
        expect(chain).to receive(:remove).with Librato::Sidekiq::ClientMiddleware
        expect(chain).to receive(:add).with Librato::Sidekiq::ClientMiddleware, config: described_class.config

        expect(config).to receive(:client_middleware).once.and_yield(chain)
        expect(Sidekiq).to receive(:configure_client).once.and_yield(config)

        described_class.register
      end
    end
  end

  describe '::check_dependencies' do
    context 'when no dependencies are provided' do
      it 'should raise an error' do
        expect {
          described_class.check_dependencies
        }.to raise_error(RuntimeError)
      end
    end

    context 'when Librato::Rails is available' do
      let(:librato_rails_version) { '1.0.0' }
      before do
        stub_const('Librato::Rails', Class.new)
        stub_const('Librato::Rails::VERSION', librato_rails_version)
        allow(described_class).to receive(:program_name).and_return('sidekiq')
        allow(STDOUT).to receive(:puts)
      end

      it 'should not raise an error' do
        expect {
          described_class.check_dependencies
        }.to_not raise_error
      end

      context 'when running a 0.10.0 version' do
        let(:librato_rails_version) { '0.10.0' }
        it 'should display a warning about LIBRATO_AUTORUN' do
          expect(STDOUT).to receive(:puts).at_least(:once)
          described_class.check_dependencies
        end
      end
      context 'when running a 1.1.0 version' do
        let(:librato_rails_version) { '1.1.0' }
        it 'should display a warning about LIBRATO_AUTORUN' do
          expect(STDOUT).to receive(:puts).at_least(:once)
          described_class.check_dependencies
        end
      end
      context 'when running an older version' do
        let(:librato_rails_version) { '0.9.0' }
        it 'should NOT display a warning about LIBRATO_AUTORUN' do
          expect(STDOUT).to_not receive(:puts)
          described_class.check_dependencies
        end
      end
    end

    context 'when Librato::Rack is available' do
      before do
        stub_const('Librato::Rack', Class.new)
      end

      it 'should not raise an error' do
        expect {
          described_class.check_dependencies
        }.to_not raise_error
      end
    end
  end
end