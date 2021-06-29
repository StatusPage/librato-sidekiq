require 'librato-sidekiq/middleware'
require 'librato-sidekiq/client_middleware'
require 'librato-sidekiq/stats'

Librato::Sidekiq::Middleware.configure
Librato::Sidekiq::ClientMiddleware.configure
