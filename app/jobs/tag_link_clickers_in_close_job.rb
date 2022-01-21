require 'close_api'
require 'customer_api'
require 'custom_fields'

class TagLinkClickersInCloseJob < ApplicationJob
  queue_as :default

  def perform(*args)
    @close_api = CloseApi.new
    @customer_api = CustomerApi.new
    @fields = CustomFields.new

    msg_slack 'tagging close contacts who have clicked a link (based on customer.io segment)'

    customer_contacts = @customer_api.get_segment(@customer_api.link_segment[:number])
    close_contacts = @close_api.all_contacts

    customer_contacts.each do |customer_contact|
      customer_email = customer_contact['attributes']['email']

      close_contact = @close_api.find_in_contacts(close_contacts, customer_email)
      next unless close_contact

      contact_payload = {}
      contact_payload[@fields.get(:clicked_link)] = 'Yes'

      _response = @close_api.update_contact(close_contact['id'], contact_payload)
    end
  end

  def msg_slack(msg)
    HTTParty.post(ENV['SLACK_URL'].to_s, body: { text: msg }.to_json)
  end
end
