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

  desc 'resets the excluded_from_sequence tag'
  task reset_exclude_from_sequence: :environment do
    @close_api = CloseApi.new
    contacts = @close_api.all_contacts
    contacts.each do |contact|
      contact_payload = {}
      contact_payload[@fields.get(:excluded_from_sequence)] = 'No'

      @close_api.update_contact contact['id'], contact_payload
    end
  end

  desc 'move all opps to inbox (in sales pipeline)'
  task :move_to_inbox_pipeline, [:number]  => :environment do |_t, args|
    sortable_statuses = []
    sortable_statuses.push @opp_status.get(:needs_contacts)
    sortable_statuses.push @opp_status.get(:nurturing_contacts)
    sortable_statuses.push @opp_status.get(:retry_sequence)
    sortable_statuses.push @opp_status.get(:in_sales_sequence)

    to_range = args[:number].to_i
    opportunities = @close_api.all_opportunities.shuffle

    opportunities[0..to_range].each do |opportunity|
      next unless opportunity['status_id'].in?(sortable_statuses)

      opportunity_payload = {}
      opportunity_payload['status_id'] = @opp_status.get(:inbox)

      @close_api.update_opportunity opportunity['id'], opportunity_payload
    end
  end

  desc 'moves x amount of of opps from inbox to outbox (waiting pipeline)'
  task :move_to_outbox_pipeline, [:number]  => :environment do |_t, args|
    sortable_statuses = []
    sortable_statuses.push @opp_status.get(:inbox)

    to_range = args[:number].to_i
    opportunities = @close_api.all_opportunities.shuffle

    opportunities[0..to_range].each do |opportunity|
      next unless opportunity['status_id'].in?(sortable_statuses)

      opportunity_payload = {}
      opportunity_payload['status_id'] = @opp_status.get(:outbox)

      @close_api.update_opportunity opportunity['id'], opportunity_payload
    end
  end

  desc 'moves x amount of opps from outbox (waiting pipeline) to inbox'
  task :move_from_outbox_to_inbox, [:number]  => :environment do |_t, args|
    sortable_statuses = []
    sortable_statuses.push @opp_status.get(:outbox)

    to_range = args[:number].to_i
    opportunities = @close_api.all_opportunities.shuffle

    opportunities[0..to_range].each do |opportunity|
      next unless opportunity['status_id'].in?(sortable_statuses)

      opportunity_payload = {}
      opportunity_payload['status_id'] = @opp_status.get(:inbox)

      @close_api.update_opportunity opportunity['id'], opportunity_payload
    end
  end
end
