require 'librato-sidekiq/middleware'
require 'librato-sidekiq/client_middleware'

Librato::Sidekiq::Middleware.configure
Librato::Sidekiq::ClientMiddleware.configure
