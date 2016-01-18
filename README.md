librato-sidekiq
=====

librato-sidekiq is a simple gem to stick Sidekiq stats and granular processing counts/times into [Librato Metrics](http://metrics.librato.com/)


Requirements and Compatibility
------------

Gems:

 * sidekiq
 * librato-rails OR librato-rack

Compatibility (tested):

 * Ruby 2.0.0
 * Ruby 2.1.0

(if you can confirm another version of Ruby, email me at scott@statuspage.io)


Usage with Rails 3.x
---------------------------

In your Gemfile:

```ruby
gem 'librato-sidekiq'
```

In `config/initializers/librato_sidekiq.rb`:

```ruby
# only needed for fine-tuning, gem will enable all metrics by default
Librato::Sidekiq.configure do |c|
  # only enable for production
  c.enabled = Rails.env.production?

  # only allow these 3 queues
  c.whitelist_queues = %w(default cron notifications)

  # ignore these worker classes
  c.blacklist_classes = %w(CronSchedulerWorker NotificationCheckerWorker)
end
```


Configuration
------------------------
Librato::Sidekiq accepts the following options.

**enabled**: Boolean, true by default

**whitelist_queues**: Array, list of queue names that will be the only ones sent to Librato (optional)

**blacklist_queues**: Array, list of queue names that will not be sent to Librato (optional)

**whitelist_classes**: Array, list of worker classes that will be the only ones sent to Librato (optional)

**blacklist_classes**: Array, list of worker classes that will not be sent to Librato (optional)


Contributing
-------------

If you have a fix you wish to provide, please fork the code, fix in your local project and then send a pull request on github.  Please ensure that you include a test which verifies your fix and update History.md with a one sentence description of your fix so you get credit as a contributor.


Thanks
------------

Mike Perham - for creating [Sidekiq](http://github.com/mperham/sidekiq), a fantastic contribution to the ruby world

Librato - for a great [metrics service](http://metrics.librato.com)


Author
----------

Scott Klein, scott@statuspage.io, [statuspage.io](https://www.statuspage.io),  If you like and use this project, please check out the [StatusPage.io service](https://www.statuspage.io/tour) for your project or company


Copyright
-----------

Copyright (c) 2013 Scott Klein. See LICENSE for details.
