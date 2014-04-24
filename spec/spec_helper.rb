require 'librato-sidekiq/middleware'
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
