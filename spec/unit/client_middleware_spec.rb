require 'spec_helper'

describe Librato::Sidekiq::ClientMiddleware do

  let(:config) { Librato::Sidekiq::Configuration.new }
  let(:middleware) { described_class.new config: config }
  let(:sidekiq_stats) { double('Sidekiq::Stats') }

  before(:each) do
    stub_const "Sidekiq::Stats", sidekiq_stats
  end

  describe '#intialize' do
    it 'should assign the config' do
      expect(middleware.config).to eq(config)
    end
  end

  describe '#call' do

    let(:meter) { double(measure: nil, increment: nil, group: nil) }

    let(:queue_name) { 'some_awesome_queue' }
    let(:some_worker_instance) { nil }
    let(:some_message) { Hash['class', double(underscore: queue_name)] }

    let(:sidekiq_stats_instance_double) do
      instance_double("Sidekiq::Stats", :enqueued => 1, :failed => 2, :scheduled_size => 3)
    end

    context 'when middleware is not enabled' do

      before(:each) { config.enabled = false }

      it { expect { |b| middleware.call(1,2,3,&b) }.to yield_with_no_args }

      it 'should not send any metrics' do
        expect(Librato).to_not receive(:group)
      end

    end

    context 'when middleware is enabled but queue is blacklisted' do

      before(:each) do
        allow(sidekiq_stats).to receive(:new).and_return(sidekiq_stats_instance_double)
        allow(Librato).to receive(:group).with('sidekiq').and_yield meter
      end

      before(:each) do
        config.enabled = true
        config.blacklist_queues = []
        config.blacklist_queues << queue_name
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
        config.enabled = true
        config.blacklist_queues = []
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
