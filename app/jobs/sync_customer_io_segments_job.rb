require 'customer_api'
require 'close_api'

# syncs up customer.io data with the database
class SyncCustomerIoSegmentsJob < ApplicationJob
  queue_as :default

  def perform(*args)
    @close_api = CloseApi.new
    @customer_api = CustomerApi.new

    # the call to get_segment retrieves a customer, and caches it in the database.
    _unsubscribed = @customer_api.get_segment(6)
    _active_subscribers = @customer_api.get_segment(7)
  end
end
