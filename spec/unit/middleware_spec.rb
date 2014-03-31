require 'librato-sidekiq/middleware'
require 'timecop'

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
      expect( Librato::Sidekiq::Middleware.configure ).to be_an_instance_of Librato::Sidekiq::Middleware
    end
  end

  describe '#reconfigure' do

    it 'should add itself to the server middleware chain' do
      chain = double()
      chain.should_receive(:remove).with Librato::Sidekiq::Middleware
      chain.should_receive(:add).with Librato::Sidekiq::Middleware, middleware.options

      config = double()
      config.should_receive(:server_middleware).once.and_yield(chain)

      Sidekiq.should_receive(:configure_server).once.and_yield(config)

      middleware.reconfigure
    end
  end

  describe '#call' do
    context 'when middleware is not enabled' do

      before(:each) { middleware.enabled = false }

      it { expect { |b| middleware.call(1,2,3,&b) }.to yield_with_no_args }

      it 'should not send any metrics' do
        Librato.should_not_receive(:group)
      end

    end

    context 'when middleware is enabled but queue is blacklisted' do

      let(:queue_name) { 'awesome_queue' }
      let(:some_worker_instance) { nil }
      let(:some_message) { nil }
      let(:sidekiq_group) do
        sg = double()
        allow(sg).to receive :measure
        allow(sg).to receive(:increment).with "processed"
        sg
      end

      before(:each) do
        sidekiq_stats_instance_double = double("Sidekiq::Stats", :enqueued => 1, :failed => 2, :scheduled_size => 3)
        Sidekiq::Stats.stub(:new).and_return(sidekiq_stats_instance_double)

        allow(Librato).to receive(:group).with('sidekiq').and_yield sidekiq_group
      end

      before(:each) do
        middleware.enabled = true
        middleware.blacklist_queues << queue_name
      end

      it 'should yield' do
        expect { |b| middleware.call(some_worker_instance, some_message, queue_name, &b) }.to yield_with_no_args
      end

      it 'should measure increment processed metric' do
        expect(sidekiq_group).to receive(:increment).with "processed"
        middleware.call(some_worker_instance, some_message, queue_name) {}
      end

      it 'should measure general metrics' do
        {"enqueued" => 1, "failed" => 2, "scheduled" => 3 }.each do |method, stat|
          expect(sidekiq_group).to receive(:measure).with(method.to_s, stat)
        end

        expect(sidekiq_group).to receive(:increment).with "processed"
        middleware.call(some_worker_instance, some_message, queue_name) {}
      end

    end

    context 'when middleware is enabled and everything is whitlisted' do

      let(:queue_name) { 'some_awesome_queue' }
      let(:some_worker_instance) { nil }
      let(:some_enqueued_value) { 20 }
      let(:some_worker_class) do
        w = double()
        allow(w).to receive(:underscore).and_return(queue_name)
        w
      end
      let(:some_message) { Hash['class', some_worker_class] }
      let(:queue_stat_hash) { Hash[queue_name, some_enqueued_value] }
      let(:sidekiq_group) do
        sg = double()
        allow(sg).to receive :measure
        allow(sg).to receive :timing
        allow(sg).to receive(:increment).with "processed"
        sg
      end
      let(:queue_group) do
        qg = double()
        allow(qg).to receive :measure
        allow(qg).to receive :timing
        allow(qg).to receive(:increment).with "processed"
        qg
      end
      let(:class_group) do
        cg = double()
        allow(cg).to receive :measure
        allow(cg).to receive :timing
        allow(cg).to receive(:increment).with "processed"
        cg
      end
      let(:sidekiq_stats_instance_double) do
        double("Sidekiq::Stats", :enqueued => 1, :failed => 2, :scheduled_size => 3)
      end

      before(:each) do
        middleware.enabled = true
        middleware.blacklist_queues = []
      end

      before do
        Timecop.freeze(Date.today + 30)
      end

      after do
        Timecop.return
      end

      before(:each) do
        Sidekiq::Stats.stub(:new).and_return(sidekiq_stats_instance_double)
        allow(queue_group).to receive(:group)
        allow(sidekiq_group).to receive(:group)
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
