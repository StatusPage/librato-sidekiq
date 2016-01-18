require 'librato-sidekiq/configuration'
require 'librato-sidekiq/sidekiq'
require 'librato-sidekiq/middleware'
require 'librato-sidekiq/client_middleware'
require 'timecop'

# Fix time
RSpec.configure do |config|
  config.before(:suite) do
    Timecop.freeze(Date.today + 30)
  end
  config.after(:suite) do
    Timecop.return
  end
end
