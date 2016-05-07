shared_context 'UPS setup' do
  before do
    shipping_config = Spree::ActiveShippingConfiguration.new
    shipping_config.ups_login = 'solidusdev'
    shipping_config.ups_password = 'S0lidusdev'
    shipping_config.ups_key = '9D0B1B1E0A6389A8'
  end
end
