# frozen_string_literal: true

require 'spec_helper'
require 'sn_foil/searcher'
require 'active_support/concern'
require_relative './shared_contexts'

RSpec.describe SnFoil::Searcher do
  include_context 'with fake policy'

  subject(:searcher) { Class.new TestSearcherClass }

  let(:instance) { searcher.new }
  let(:query) { instance.search(params).to_query }
  let(:params) { {} }
  let(:canary) { Canary.new }

  before do
    searcher.model_class model_double
    allow(model_double).to receive(:all).and_return(FakeScope.new(Person, '"people".*'))
  end

  context 'with params value that include \'true\'(String)' do
    let(:params) { { canary: canary, parameter: 'true' } }

    before do
      searcher.filter do |scope, params|
        params[:canary].sing(params)
        scope
      end
    end

    it 'converts the values to true(Boolean)' do
      query
      expect(canary.song[0][:data][:parameter]).to be true
      expect(canary.song[0][:data][:parameter]).not_to eq 'true'
    end
  end

  context 'with params value that include \'false\'(String)' do
    let(:params) { { canary: canary, parameter: 'false' } }

    before do
      searcher.filter do |scope, params|
        params[:canary].sing(params)
        scope
      end
    end

    it 'converts the values to false(Boolean)' do
      query
      expect(canary.song[0][:data][:parameter]).to be false
      expect(canary.song[0][:data][:parameter]).not_to eq 'false'
    end
  end

  describe '#initialize' do
    context 'when a scope is provided' do
      let(:instance) { searcher.new(scope: FakeScope.new(Person, '"doctors".*')) }

      it 'sets the internal scope to the provided scope' do
        expect(query).to match(/"doctors".\*/)
      end
    end

    context 'when a scope isn\'t provided' do
      it 'sets the internal scope to the model' do
        expect(query).to match(/"people".\*/)
      end
    end
  end

  describe 'self#model_class' do
    it 'sets the internal model class' do
      expect(instance.model_class.to_s).to match(/Person/)
    end
  end

  describe 'self#setup' do
    let(:params) { { canary: canary } }

    before do
      searcher.filter do |scope, _|
        params[:canary].sing(:filter)
        scope
      end

      searcher.setup do |scope, params|
        params[:canary].sing(:setup_block)
        scope
      end
    end

    it 'gets called before filters' do
      query
      expect(canary.song[0][:data]).to eq(:setup_block)
      expect(canary.song[1][:data]).to eq(:filter)
    end

    context 'with a block' do
      it 'calls the block' do
        query
        expect(canary.song[0][:data]).to eq(:setup_block)
      end
    end

    context 'with a method' do
      before do
        searcher.define_method(:setup_method) do |scope, params|
          params[:canary].sing(:setup_method)
          scope
        end
        searcher.setup :setup_method
      end

      it 'calls the method' do
        query
        expect(canary.song[0][:data]).to eq(:setup_method)
      end
    end
  end

  describe 'self#filter' do
    let(:canary) { Canary.new }
    let(:params) { { canary: canary } }

    context 'with a block' do
      before do
        searcher.filter do |scope, params|
          params[:canary].sing(:filter_block)
          scope
        end
      end

      it 'calls the block' do
        query
        expect(canary.song[0][:data]).to eq(:filter_block)
      end
    end

    context 'with a method' do
      before do
        searcher.define_method(:filter_method) do |scope, params|
          params[:canary].sing(:filter_method)
          scope
        end
        searcher.filter :filter_method
      end

      it 'calls the method' do
        query
        expect(canary.song[0][:data]).to eq(:filter_method)
      end
    end

    context 'with options[:if]' do
      context 'when the provided lamba returns true' do
        before do
          searcher.filter(if: ->(_) { true }) do |scope, _|
            scope.where('"people"."client_id" = 1')
          end
        end

        it 'adds the filter to the query' do
          expect(query).to match(/"people"."client_id" = 1/)
        end
      end

      context 'when the provided lamba returns false' do
        before do
          searcher.filter(if: ->(_) { false }) do |scope, _|
            scope.where('"people"."client_id" = 2')
          end
        end

        it 'doesn\'t add the filter to the query' do
          expect(query).not_to match(/"people"."client_id" = 2/)
        end
      end
    end

    context 'with options[:unless]' do
      context 'when the provided lamba returns true' do
        before do
          searcher.filter(unless: ->(_) { true }) do |scope, _|
            scope.where('"people"."client_id" = 3')
          end
        end

        it 'doesn\'t add the filter to the query' do
          expect(query).not_to match(/"people"."client_id" = 3/)
        end
      end

      context 'when the provided lamba returns false' do
        before do
          searcher.filter(unless: ->(_) { false }) do |scope, _|
            scope.where('"people"."client_id" = 4')
          end
        end

        it 'adds the filter to the query' do
          expect(query).to match(/"people"."client_id" = 4/)
        end
      end
    end
  end

  describe '#filter' do
    before do
      def instance.filter
        FakeScope.new(Person, '"farmers".*')
      end
    end

    it 'overrides the default scope and uses the return' do
      expect(query).to match(/"farmers".\*/)
      expect(query).not_to match(/"people".\*/)
    end
  end

  describe '#results' do
    before do
      searcher.filter { |scope, _| scope.where('"people"."client_id" = 6') }
    end

    it 'returns the scope of the built query' do
      expect(query).to match(/"people"."client_id" = 6/)
    end
  end
end

module PersonExtension
  extend ActiveSupport::Concern

  class_methods do
    def where(addition)
      FakeScope.new(Person).where(addition)
    end
  end
end

class Person
  prepend PersonExtension
end

class TestSearcherClass
  include SnFoil::Searcher
end

class FakeScope
  attr_reader :model, :scope
  def initialize(model, scope = '')
    @model = model
    @scope = scope
  end

  def where(addition)
    @scope += ' ' unless @scope.empty?
    @scope += addition
    self
  end

  def to_query
    scope
  end
end
