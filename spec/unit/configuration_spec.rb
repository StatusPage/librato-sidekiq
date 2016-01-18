require 'spec_helper'

describe Librato::Sidekiq::Configuration do
  describe '#initialize' do
    it 'should set enabled to true' do
      expect(subject.enabled).to eq(true)
    end

    described_class::ARRAY_OPTIONS.each do |o|
      it "should set #{o} to a blank array" do
        expect(subject.send(o)).to eq([])
      end
    end
  end

  shared_examples_for 'whitelist checks' do |option, method, list, value|
    context 'when it is empty' do
      before do
        expect(subject.send(option)).to be_empty
      end
      it 'should return true' do
        expect(subject.send(method, value)).to eq(true)
      end
    end
    context 'when it is not empty' do
      before do
        subject.send("#{option}=", list)
      end

      it 'should be true when the list contains the entry' do
        expect(subject.send(method, value)).to eq(true)
      end

      it 'should be false when the list does not contain the entry' do
        expect(subject.send(method, 'other')).to eq(false)
      end
    end
  end

  shared_examples_for 'blacklist checks' do |option, method, list, value|
    context 'when it is empty' do
      before do
        expect(subject.send(option)).to be_empty
      end
      it 'should return false' do
        expect(subject.send(method, value)).to eq(false)
      end
    end
    context 'when it is not empty' do
      before do
        subject.send("#{option}=", list)
      end

      it 'should be false when the list contains the entry' do
        expect(subject.send(method, value)).to eq(true)
      end

      it 'should be true when the list does not contain the entry' do
        expect(subject.send(method, 'other')).to eq(false)
      end
    end

  end

  describe '#queue_in_whitelist' do
    include_examples 'whitelist checks', :whitelist_queues, :queue_in_whitelist, ['default'], 'default'
  end

  describe '#queue_in_blacklist' do
    include_examples 'blacklist checks', :blacklist_queues, :queue_in_blacklist, ['default'], 'default'
  end

  describe '#class_in_whitelist' do
    include_examples 'whitelist checks', :whitelist_classes, :class_in_whitelist, ['Array'], []
  end

  describe '#class_in_blacklist' do
    include_examples 'blacklist checks', :blacklist_classes, :class_in_blacklist, ['Array'], []
  end

  describe '#allowed_to_submit' do
    it 'when no lists defined it should always be true' do
      expect(subject.allowed_to_submit('default', [])).to eq(true)
    end
  end
end