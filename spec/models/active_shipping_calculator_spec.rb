require 'spec_helper'

describe Spree::Calculator::Shipping do
  # NOTE: All specs will use the bogus calculator
  # (no login information needed)

  let(:address) { FactoryGirl.create(:address) }
  let(:variant_1) { FactoryGirl.create(:variant, weight: 1) }
  let(:variant_2) { FactoryGirl.create(:variant, weight: 2) }
  let!(:stock_location) { FactoryGirl.create(:stock_location) }
  let!(:order) do
    FactoryGirl.create(:order_with_line_items, ship_address: address, line_items_count: 2,
                       line_items_attributes: [{ quantity: 2, variant: variant_1}, { quantity: 2, variant: variant_2 }] )
  end

  let(:carrier) { Spree::ActiveShipping::BogusCarrier.new }
  let(:calculator) { Spree::Calculator::Shipping::ActiveShipping::BogusCalculator.new }
  let(:response) { double('response', rates: rates, params: {}) }
  let(:package) { order.shipments.first.to_package }

  before(:each) do
    order.create_proposed_shipments
    Spree::ActiveShipping::Config.set(units: 'imperial')
    Spree::ActiveShipping::Config.set(unit_multiplier: 1)
    Spree::ActiveShipping::Config.set(handling_fee: 0)
    allow(calculator).to receive(:carrier).and_return(carrier)
    # Since the response can be cached, we explicitly clear cache
    # so each test can be run from a clean slate
    Rails.cache.delete(calculator.send(:cache_key, package))
  end

  describe 'package.order' do
    it { expect(package.order).to eq(order) }
    it { expect(package.order.ship_address).to eq(address) }
    it { expect(package.order.ship_address.country.iso).to eq('US') }
    it { expect(package.stock_location).to eq(stock_location) }
  end

  describe 'available' do
    context 'when rates are available' do
      let(:rates) do
        [double('rate', service_name: 'Bogus Calculator', price: 1)]
      end

      before do
        allow(carrier).to receive(:find_rates) { response }
      end

      it 'should return true' do
        expect(calculator.available?(package)).to eq true
      end

      it 'should use zero as a valid weight for service' do
        allow(calculator).to receive(:max_weight_for_country).and_return(0)
        expect(calculator.available?(package)).to eq true
      end
    end

    context 'when rates are not available' do
      let(:rates) { [] }

      before do
        allow(carrier).to receive(:find_rates) { response }
      end

      it 'should return false' do
        expect(calculator.available?(package)).to eq false
      end
    end

    context 'when there is an error retrieving the rates' do
      before do
        allow(carrier).to receive(:find_rates).and_raise(::ActiveShipping::ResponseError)
      end

      it 'should return false' do
        expect(calculator.available?(package)).to eq false
      end
    end
  end

  describe 'available?' do
    let(:rates) do
      [double('rate', service_name: 'Bogus Calculator', price: 999)]
    end

    # regression test for #164 and #171
    it 'should not return rates if the weight requirements for the destination country are not met' do
      # if max_weight_for_country is nil -> the carrier does not ship to that country
      # if max_weight_for_country is 0 -> the carrier does not have weight restrictions to that country
      allow(calculator).to receive(:max_weight_for_country).and_return(nil)
      expect(calculator).to receive(:is_package_shippable?).and_raise(Spree::ShippingError)
      expect(calculator.available?(package)).to eq false
    end
  end

  describe 'compute' do
    subject { calculator.compute(package) }

    let(:rates) do
      [double('rate', service_name: 'Bogus Calculator', price: 999)]
    end

    it 'should use the carrier supplied in the initializer' do
      expect(carrier).to receive(:find_rates) { response }
      subject
    end

    # It's passing but probably because it's not checking anything
    xit 'should ignore variants that have a nil weight' do
      variant = order.line_items.first.variant
      variant.weight = nil
      variant.save
      subject
    end

    xit 'should create a package with the correct total weight in ounces' do
      # (10 * 2 + 5.25 * 1) * 16 = 404
      expect(Package).to receive(:new).with(404, [], units: :imperial)
      subject
    end

    it 'should check the cache first before finding rates' do
      # Since the cache is cleared between the tests, cache.fetch will return a miss,
      # but by passing a block { Hash.new }, the return value of the block will be
      # written under the given cache key
      Rails.cache.fetch(calculator.send(:cache_key, package)) { Hash.new }
      expect(carrier).not_to receive(:find_rates)
      subject
    end

    context 'with valid response' do
      before do
        allow(carrier).to receive(:find_rates) { response }
      end

      it "should return rate based on calculator's service_name" do
        allow(calculator.class).to receive(:description) { 'Bogus Calculator' }
        expect(subject).to eq 9.99
      end

      it 'should include handling_fee when configured' do
        Spree::ActiveShipping::Config.set(handling_fee: 100)
        allow(calculator.class).to receive(:description) { 'Bogus Calculator' }
        expect(subject).to eq 10.99
      end

      it 'should return nil if service_name is not found in rate_hash' do
        allow(calculator.class).to receive(:description) { 'Service name not found' }
        expect(subject).to be_nil
      end
    end

    context 'with invalid response' do
      before do
        allow(carrier).to receive(:find_rates).and_raise(::ActiveShipping::ResponseError)
      end

      it 'should raise a Spree::ShippingError' do
        expect{ subject }.to raise_exception(Spree::ShippingError)
      end
    end
  end

  describe 'service_name' do
    it 'should return description when not defined' do
      expect(calculator.class.service_name).to eq calculator.description
    end
  end
end
