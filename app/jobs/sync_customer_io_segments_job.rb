require 'customer_api'
require 'close_api'

# syncs up customer.io data with the database
class SyncCustomerIoSegmentsJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    @close_api = CloseApi.new
    @customer_api = CustomerApi.new

    msg_slack('syncing up the customer.io job segments to the orchestrator')

    # the call to get_segment retrieves a customer, and caches it in the database.
    _unsubscribed = @customer_api.get_segment(6)
    _active_subscribers = @customer_api.get_segment(7)
  end

  def msg_slack(msg)
    HTTParty.post(ENV['SLACK_URL'].to_s, body: { text: msg }.to_json)
  end
end
