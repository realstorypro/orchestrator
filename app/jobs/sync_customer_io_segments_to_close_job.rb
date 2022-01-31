require 'close_api'
require 'customer_api'
require 'custom_fields'

# syncs the segments from customer.io to close.com
class SyncCustomerIoSegmentsToCloseJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    @close_api = CloseApi.new
    @customer_api = CustomerApi.new
    @fields = CustomFields.new

    msg_slack 'syncing customer.io segments to close'

    close_contacts = @close_api.all_contacts

    @customer_api.segments.each do |segment|
      customer_contacts = @customer_api.get_segment(segment[:number])
      update_close_contacts(close_contacts, customer_contacts, segment)
    end
  end

  def update_close_contacts(close_contacts, customer_contacts, customer_segment)
    customer_contacts.each do |customer_contact|
      customer_email = customer_contact['attributes']['email']
      customer_created_at = Time.at(
        customer_contact['timestamps']['cio_id']
      ).strftime('%m/%d/%Y')

      close_contact = @close_api.find_in_contacts(close_contacts, customer_email)

      next unless close_contact

      contact_payload = {}

      # we only want to update the customer if the new segment is of a higher rank
      # this greatly speeds up the updates
      rank = @customer_api.segment_rank(customer_segment[:number], close_contact[@fields.get(:customer_segment)])
      next unless rank == 'superior'

      contact_payload[@fields.get(:customer_segment)] = customer_segment[:name]
      contact_payload[@fields.get(:needs_nurturing)] = 'No'
      contact_payload[@fields.get(:nurture_start_date)] = customer_created_at
      _response = @close_api.update_contact(close_contact['id'], contact_payload)
    end
  end

  def msg_slack(msg)
    HTTParty.post(ENV['SLACK_URL'].to_s, body: { text: msg }.to_json)
  end
end
