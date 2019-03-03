require 'datadog/statsd'

class SendMetricsToCloudWatchWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'misc', retry: 0, backtrace: false

  def perform
    client = CloudWatchClient.new
    send_sidekiq_metrics(client)
    send_google_analytics_metrics(client)

    # begin
    #   rate_limits = Bot.rate_limit
    # rescue => e
    #   logger.warn "#{e.class} #{e.message}"
    #   rate_limits = []
    # end
    # datadog(queue_values, ga_active_users, rate_limits)

  rescue => e
    logger.warn "#{e.class} #{e.message}"
    logger.info e.backtrace.join("\n")
  end

  def datadog(values, ga_active_users, rate_limits)
    statsd = Datadog::Statsd.new('localhost', 8125)

    values.each do |name, size, latency|
      statsd.gauge("sidekiq.queues.#{name}.size", size)
      statsd.gauge("sidekiq.queues.#{name}.latency", latency)
    end
    statsd.gauge('google.analytics.active_users', ga_active_users)

    rate_limits.each do |rl|
      %i(verify_credentials friend_ids follower_ids).each do |endpoint|
        statsd.gauge("twitter.rate_limits.#{endpoint}.remaining", rl[endpoint][:remaining], tags: ["bot_id:#{rl[:id]}"])
      end
    end
  end

  private

  def send_sidekiq_metrics(client)
    # region = %x(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed -e 's/.$//')
    # instance_id=%x(curl -s http://169.254.169.254/latest/meta-data/instance-id)

    Sidekiq::Queue.all.each do |queue|
      options = {namespace: "Sidekiq/#{Rails.env}", dimensions: [{name: 'QueueName', value: queue.name}]}
      client.put_metric_data('QueueSize', queue.size, options)
      client.put_metric_data('QueueLatency', queue.latency, options)
    end

  end

  def send_google_analytics_metrics(client)
    GoogleAnalyticsClient.new.realtime_data(
        metrics: %w(rt:activeUsers),
        dimensions: %w(rt:deviceCategory rt:medium rt:source rt:userType)
    ).rows.each do |device_category, medium, source, user_type, active_users|
      dimensions = [
          {name: 'rt:deviceCategory', value: device_category},
          {name: 'rt:medium', value: medium},
          {name: 'rt:source', value: source},
          {name: 'rt:userType', value: user_type}
      ]

      options = {namespace: "Google Analytics/#{Rails.env}", dimensions: dimensions}
      client.put_metric_data('rt:activeUsers', active_users, options)
    end
  end
end