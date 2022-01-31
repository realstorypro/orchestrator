require 'close_api'
require 'custom_fields'
require 'opportunity_statuses'

# Sorts opportunities between pipelines
class SortOpportunitiesInCloseJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    @close_api = CloseApi.new
    @fields = CustomFields.new
    @opp_status = OpportunityStatuses.new

    # 1. Moves opportunity to 'Retry Sequence' if the sequence has not been in
    # the 'active' state for more then 3 days.
    sort_sales_pipeline

    # 2. Sorts the contacts in 'Inbox', 'Needs Contacts', 'Nurturing Contacts' and 'Retry Sequence'
    # Placing them into the 'Needs Contacts', 'Nurturing Contacts' and 'Ready for Sequence'
    sort_other_pipelines
  end

  def sort_sales_pipeline
    msg_slack 'sorting opportunities in **sales pipeline **'

    # 1. Lets get all opportunities
    opportunities = @close_api.all_opportunities

    # 2. Select opportunities in the 'In Sales' stage
    opportunities.select! { |o| o['status_id'] == @opp_status.get(:in_sales_sequence) }

    # 3. Loop over the opportunities in the 'In Sales' stage
    opportunities.each do |opportunity|
      # 4. Get the current contact for the Opportunity
      contact_id = opportunity['contact_id']

      # 5. Get the sequence subscriptions associated with the contact
      sequences = @close_api.find_sequence_by_contact_id(contact_id)

      recycle_opportunity = false

      # 6. Search through the sequences associated w/ the opportunity
      # and determine if the opportunity needs to be recycled
      sequences.each do |sequence|
        date_updated = DateTime.parse(sequence['date_updated'])
        date_difference = date_updated.step(Date.today).count

        # 6.1 We are only looking at sequences older then 3 and less then 10 days
        next unless date_difference > 3 && date_difference < 10

        # 6.2 We want everything but the sequences in active status
        next if sequence['status'].in? %w[active]

        recycle_opportunity = true
      end

      next unless recycle_opportunity

      # 7. set the contact to the do not sequence
      contact_payload = {}
      contact_payload[@fields.get(:excluded_from_sequence)] = 'Yes'

      @close_api.update_contact contact_id, contact_payload

      # 8. Set opportunity status to retry
      opportunity_payload = {}
      opportunity_payload['status_id'] = @opp_status.get(:retry_sequence)

      @close_api.update_opportunity opportunity['id'], opportunity_payload
    end
  end

  def sort_other_pipelines
    msg_slack 'sorting opportunities in **inbox**, **needs contacts**, **nurturing contacts** and **retry sequence**'

    contacts = @close_api.all_contacts

    sortable_statuses = []
    sortable_statuses.push @opp_status.get(:inbox)
    sortable_statuses.push @opp_status.get(:needs_contacts)
    sortable_statuses.push @opp_status.get(:nurturing_contacts)
    sortable_statuses.push @opp_status.get(:retry_sequence)

    @close_api.all_opportunities.each do |opportunity|
      next unless opportunity['status_id'].in?(sortable_statuses)

      lead = @close_api.find_lead(opportunity['lead_id'])
      ready_decision_makers = @close_api.ready_decision_makers(contacts, lead['id'])

      payload = {}

      # check if the lead has available decision makers
      payload['status_id'] = if (lead[@fields.get(:available_decision_makers)]).positive?
                               # decide if we're ready to seq or the lead still needs nurturing
                               if ready_decision_makers.count.positive?
                                 @opp_status.get(:ready_for_sequence)
                               else
                                 @opp_status.get(:nurturing_contacts)
                               end
                             else
                               # move things over to need contacts since we don't have any decision makers
                               @opp_status.get(:needs_contacts)
                             end

      puts "updating: #{opportunity['id']}", payload

      @close_api.update_opportunity(opportunity['id'], payload)
    end
  end

  private

  def msg_slack(msg)
    HTTParty.post(ENV['SLACK_URL'].to_s, body: { text: msg }.to_json)
  end
end
