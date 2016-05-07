require 'spec_helper'

module ActiveShipping
  describe Spree::Calculator::Shipping::Ups::Express do
    include_context 'checkout setup'
    include_context 'UPS setup'

    around do |example|
      WebMock.allow_net_connect!
      example.run
      WebMock.disable_net_connect!
    end

    let(:destination) { create :address,
      firstname: 'John',
      lastname: 'Doe',
      company: 'Company',
      address1: '4157 Lawnview Ave',
      city: 'Dallas',
      state: create(:state_with_autodiscover, state_code: 'TX'),
      zipcode: '75227',
      phone: "(555) 555-5555"
    }
    let(:variant_1) { FactoryGirl.create(:variant, weight: 1) }
    let(:variant_2) { FactoryGirl.create(:variant, weight: 2) }
    let(:order) do
      FactoryGirl.create(:order_with_line_items, stock_location: stock_location, ship_address: destination, line_items_count: 2,
                       line_items_attributes: [{ quantity: 2, variant: variant_1}, { quantity: 2, variant: variant_2 }] )
    end
    let(:package) { order.shipments.first.to_package }

    describe "#retrieve_rates" do
      subject { described_class.new.compute_package(package) }

      it "should use zero as a valid weight for service" do

        expect(subject).to be(1)
      end
    end
  end
end
