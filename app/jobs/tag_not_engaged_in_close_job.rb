require 'close_api'
require 'customer_api'
require 'custom_fields'

# Tags close contacts who have clicked a link (based on customer.io segment)
class TagNotEngagedInCloseJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    @close_api = CloseApi.new
    @customer_api = CustomerApi.new
    @fields = CustomFields.new

    msg_slack 'Tagging Close contacts who have have not engaged with emails'

    customer_contacts = @customer_api.get_segment(@customer_api.not_engaged[:number])
    close_contacts = @close_api.all_contacts

    customer_contacts.each do |customer_contact|
      customer_email = customer_contact['attributes']['email']

      close_contact = @close_api.find_in_contacts(close_contacts, customer_email)
      next unless close_contact

      contact_payload = {}
      contact_payload[@fields.get(:not_engaged)] = 'Yes'

      _response = @close_api.update_contact(close_contact['id'], contact_payload)
    end
  end

  def msg_slack(msg)
    HTTParty.post(ENV['SLACK_URL'].to_s, body: { text: msg }.to_json)
  end
end
