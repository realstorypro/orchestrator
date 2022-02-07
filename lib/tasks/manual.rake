require 'close_api'
require 'custom_fields'
require 'opportunity_statuses'
require 'lead_statuses'

namespace :manual do
  @close_api = CloseApi.new
  @fields = CustomFields.new
  @opp_status = OpportunityStatuses.new
  @lead_status = LeadStatuses.new

  # we are converting leads to opportunities based on the following criteria
  # 1. The lead has no opps attached to it.
  # 2. The lead is not in 'bad fit' status.
  # 3. The contacts have not received emails.
  desc 'turns leads into opportunities'
  task leads_to_opps: :environment do
    puts 'turning leads into opps'

    close_leads = @close_api.search('no_opps__no_sent_emails__not_bad_fit.json')
    close_leads.each do |lead|
      payload = {
        value: 2700000,
        value_period: 'annual',
        confidence: 1,
        lead_id: lead['id'],
        status_id: @opp_status.get(:inbox)
      }

      rsp = @close_api.create_opportunity(payload)
      puts rsp
    end
  end
end
