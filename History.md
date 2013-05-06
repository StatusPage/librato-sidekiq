librato-sidekiq changelog
=====================

HEAD
=======
- Drop librato-rails dependency since librato-rack is API compliant. this is now an implicit dependency and not managed by gemspec

0.1.0
=======
- Initial commit
- Each completed job measures current stats, timing, and increments processed for queue and worker name

