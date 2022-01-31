require 'close_api'
require 'custom_fields'

# Sends contacts with 'Needs Nurturing' field set to 'Yes' to customer.io
class NurtureCloseContactsInCustomerIoJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    @close_api = CloseApi.new
    @fields = CustomFields.new
    @customer_io = Customerio::Client.new(ENV['CUSTOMER_IO_SITE_ID'], ENV['CUSTOMER_IO_KEY'])

    nurture_contacts
  end

  def nurture_contacts
    msg_slack('nurturing close contacts in customer.io')

    @close_api.all_contacts.each do |contact|
      next unless contact[@fields.get(:needs_nurturing)] == 'Yes'

      email = contact['emails'].reject { |c| c['email'].nil? }[0]
      if email.nil?
        msg_slack "#{contact['name']} from doesn't have an email but needs nurturing! Please fix."
        next
      else
        lead = @close_api.find_lead(contact['lead_id'])

        # assigning email to a new variable to keep things simple
        the_email = email['email']
        first_name = contact['name'].split(' ')[0]
        last_name = contact['name'].split(' ')[1]
        title = contact['title']
        company = lead.parsed_response['display_name']
        url = lead.parsed_response['url']

        puts the_email, first_name, last_name, title, company, url
        puts '---- uploading to customer.io from sync----'

        @customer_io.identify(
          id: the_email,
          email: the_email,
          created_at: (Date.today).strftime('%F'),
          last_name: last_name,
          first_name: first_name,
          title: title,
          company: company,
          url: url,
          source: 'close.com'
        )

        @customer_io.track(the_email, 'begin nurture')
      end
    end
  end

  private

  def msg_slack(msg)
    HTTParty.post(ENV['SLACK_URL'].to_s, body: { text: msg }.to_json)
  end
end
