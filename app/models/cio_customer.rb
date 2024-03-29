# Used to speedup interacting w/ Customer.IO (via caching)
class CioCustomer < ApplicationRecord
  CUSTOMER_IO_AUTH = { "Authorization": "Bearer #{ENV['CUSTOMER_IO_API_KEY']}" }.freeze
  CUSTOMER_API_BASE = 'https://beta-api.customer.io/v1/api/'.freeze

  def remote_sync
    sync = false

    # only sync IF
    # 1. the data is nil OR
    # 2 the customer has been updated more then 5 days ago
    sync = true if data.nil?
    sync = true if updated_at < 10.day.ago

    return unless sync

    customer_url = URI("#{CUSTOMER_API_BASE}customers/#{cio_id}/attributes")
    rsp = HTTParty.get(customer_url, headers: CUSTOMER_IO_AUTH)
    update(data: rsp.parsed_response)
  end
end
