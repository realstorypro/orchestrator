require 'close_api'
require 'customer_api'
require 'custom_fields'
require 'ai'

# Tags contacts that are ready for an email
class TagReadyForEmailInCloseJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    @close_api = CloseApi.new
    @customer_api = CustomerApi.new
    @fields = CustomFields.new
    @ai = Ai.new

    msg_slack 'Tagging close contacts who are ready for email (__Done by AI__)'

    contacts = @close_api.all_contacts
    contacts.each do |contact|
      nurture_start_date = contact[@fields.get(:nurture_start_date)]
      customer_segment = contact[@fields.get(:customer_segment)]
      clicked_link = contact[@fields.get(:clicked_link)]

      next if nurture_start_date.nil?
      next if customer_segment.nil?

      weeks_old = Date.parse(nurture_start_date).step(Date.today, 7).count
      # anything over 7 weeks old is still counted as 7 weeks
      weeks_old = 7 if weeks_old > 7

      segment_score = @customer_api.get_segment_score(customer_segment)
      link_score = if clicked_link == 'Yes'
                     1
                   else
                     0
                   end

      # last two items are set to zero since we don't have leadfeeder hooked up
      send_email = @ai.send_email?(weeks_old, segment_score, link_score, 0, 0)

      next unless send_email

      # Tag the contact as ready for email
      payload = {}
      payload[@fields.get(:ready_for_email)] = 'Yes'
      @close_api.update_contact(contact['id'], payload)
    end
  end

  def msg_slack(msg)
    HTTParty.post(ENV['SLACK_URL'].to_s, body: { text: msg }.to_json)
  end
end
