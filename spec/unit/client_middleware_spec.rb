require 'spec_helper'

describe Librato::Sidekiq::ClientMiddleware do

  before(:each) do
    stub_const "Librato::Rails", Class.new
    stub_const "Sidekiq", Module.new
    stub_const "Sidekiq::Stats", Class.new
  end

  let(:middleware) do
    allow(Sidekiq).to receive(:configure_client)
    Librato::Sidekiq::ClientMiddleware.new
  end

  describe '#initialize' do
    it 'should not call reconfigure' do
      expect(Sidekiq).not_to receive(:configure_client)
      Librato::Sidekiq::ClientMiddleware.new
    end
  end

  describe '#configure' do

    before(:each) do
      allow(described_class).to receive(:reconfigure)
    end

    it 'should yield with it self as argument' do
      expect { |b| Librato::Sidekiq::ClientMiddleware.configure &b }.to yield_with_args(Librato::Sidekiq::ClientMiddleware)
    end

    it 'should call reconfigure' do
      expect(described_class).to receive(:reconfigure)
      described_class.configure
    end

    it 'should return a new instance' do
      expect(Librato::Sidekiq::ClientMiddleware.configure).to be_an_instance_of Librato::Sidekiq::ClientMiddleware
    end

  end

  describe '.reconfigure' do

    let(:chain) { double() }
    let(:config) { double() }

    it 'should add itself to the server middleware chain' do
      expect(chain).to receive(:remove).with Librato::Sidekiq::ClientMiddleware
      expect(chain).to receive(:add).with Librato::Sidekiq::ClientMiddleware,
                                          described_class.options

      expect(config).to receive(:client_middleware).once.and_yield(chain)
      expect(Sidekiq).to receive(:configure_client).once.and_yield(config)

      described_class.reconfigure
    end
  end

  describe '#call' do

    let(:meter) { double(measure: nil, increment: nil, group: nil) }

    let(:queue_name) { 'some_awesome_queue' }
    let(:some_worker_instance) { nil }
    let(:some_message) { Hash['class', double(underscore: queue_name)] }

    let(:sidekiq_stats_instance_double) do
      double("Sidekiq::Stats", :enqueued => 1, :failed => 2, :scheduled_size => 3)
    end

    context 'when middleware is not enabled' do

      before(:each) { middleware.enabled = false }

      it { expect { |b| middleware.call(1,2,3,&b) }.to yield_with_no_args }

      it 'should not send any metrics' do
        Librato.should_not_receive(:group)
      end

    end

    context 'when middleware is enabled but queue is blacklisted' do

      before(:each) do
        allow(Sidekiq::Stats).to receive(:new).and_return(sidekiq_stats_instance_double)
        allow(Librato).to receive(:group).with('sidekiq').and_yield meter
      end

      before(:each) do
        middleware.enabled = true
        middleware.blacklist_queues = []
        middleware.blacklist_queues << queue_name
      end

      it { expect { |b| middleware.call(some_worker_instance, some_message, queue_name, &b) }.to yield_with_no_args }

      it 'should measure increment queued metric' do
        expect(meter).to receive(:increment).with 'queued'
        middleware.call(some_worker_instance, some_message, queue_name) {}
      end

    end

    context 'when middleware is enabled and everything is whitlisted' do

      let(:sidekiq_group) { double(measure: nil, increment: nil, group: nil) }
      let(:queue_group) { double(measure: nil, increment: nil, timing: nil, group: nil) }
      let(:class_group) { double(measure: nil, increment: nil, timing: nil, group: nil) }

      before(:each) do
        middleware.enabled = true
        middleware.blacklist_queues = []
      end

      before(:each) do
        allow(Sidekiq::Stats).to receive(:new).and_return(sidekiq_stats_instance_double)
        allow(Librato).to receive(:group).with('sidekiq').and_yield(sidekiq_group)
        allow(sidekiq_stats_instance_double).to receive(:queues)
      end

      it 'should measure queue metrics' do
        expect(sidekiq_group).to receive(:group).and_yield(queue_group)

        expect(queue_group).to receive(:increment).with "queued"

        middleware.call(some_worker_instance, some_message, queue_name) {}
      end

      it 'should measure class metrics' do
        expect(sidekiq_group).to receive(:group).and_yield(queue_group)
        expect(queue_group).to receive(:group).with(queue_name).and_yield(class_group)

        expect(class_group).to receive(:increment).with "queued"

        middleware.call(some_worker_instance, some_message, queue_name) {}
      end

    end

  end

end
