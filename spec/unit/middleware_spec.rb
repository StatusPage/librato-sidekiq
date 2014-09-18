require 'spec_helper'

describe Librato::Sidekiq::Middleware do

  before(:each) do
    stub_const "Librato::Rails", Class.new
    stub_const "Sidekiq", Module.new
    stub_const "Sidekiq::Stats", Class.new
  end

  let(:middleware) do
    allow(Sidekiq).to receive(:configure_server)
    Librato::Sidekiq::Middleware.new
  end

  describe '#intialize' do
    it 'should call reconfigure' do
      expect(Sidekiq).to receive(:configure_server)
      Librato::Sidekiq::Middleware.new
    end
  end

  describe '#configure' do

    before(:each) { Sidekiq.should_receive(:configure_server) }

    it 'should yield with it self as argument' do
      expect { |b| Librato::Sidekiq::Middleware.configure &b }.to yield_with_args(Librato::Sidekiq::Middleware)
    end

    it 'should return a new instance' do
      expect(Librato::Sidekiq::Middleware.configure).to be_an_instance_of Librato::Sidekiq::Middleware
    end

  end

  describe '#reconfigure' do

    let(:chain) { double() }
    let(:config) { spy() }

    it 'should add itself to the server middleware chain' do
      expect(chain).to receive(:remove).with Librato::Sidekiq::Middleware
      expect(chain).to receive(:add).with Librato::Sidekiq::Middleware, middleware.options

      expect(config).to receive(:server_middleware).once.and_yield(chain)
      expect(Sidekiq).to receive(:configure_server).once.and_yield(config)

      middleware.reconfigure
    end

    it 'should add ClientMiddleware to the client middleware chain' do
      expect(chain).to receive(:remove).with Librato::Sidekiq::ClientMiddleware
      expect(chain).to receive(:add).with Librato::Sidekiq::ClientMiddleware, middleware.options

      expect(config).to receive(:client_middleware).once.and_yield(chain)
      expect(Sidekiq).to receive(:configure_server).once.and_yield(config)

      middleware.reconfigure
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

      it 'should measure increment processed metric' do
        expect(meter).to receive(:increment).with "processed"
        middleware.call(some_worker_instance, some_message, queue_name) {}
      end

      it 'should measure general metrics' do
        {"enqueued" => 1, "failed" => 2, "scheduled" => 3 }.each do |method, stat|
          expect(meter).to receive(:measure).with(method.to_s, stat)
        end
        expect(meter).to receive(:increment).with "processed"

        middleware.call(some_worker_instance, some_message, queue_name) {}
      end

    end

    context 'when middleware is enabled and everything is whitlisted' do

      let(:some_enqueued_value) { 20 }
      let(:queue_stat_hash) { Hash[queue_name, some_enqueued_value] }
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
        allow(sidekiq_stats_instance_double).to receive(:queues).and_return queue_stat_hash
      end

      it 'should measure queue metrics' do
        expect(sidekiq_stats_instance_double).to receive(:queues).and_return queue_stat_hash

        expect(sidekiq_group).to receive(:group).and_yield(queue_group)

        expect(queue_group).to receive(:increment).with "processed"
        expect(queue_group).to receive(:timing).with "time", 0
        expect(queue_group).to receive(:measure).with "enqueued", some_enqueued_value

        middleware.call(some_worker_instance, some_message, queue_name) {}
      end

      it 'should measure class metrics' do
        expect(sidekiq_group).to receive(:group).and_yield(queue_group)
        expect(queue_group).to receive(:group).with(queue_name).and_yield(class_group)

        expect(class_group).to receive(:increment).with "processed"
        expect(class_group).to receive(:timing).with "time", 0

        middleware.call(some_worker_instance, some_message, queue_name) {}
      end

    end

  end

end
