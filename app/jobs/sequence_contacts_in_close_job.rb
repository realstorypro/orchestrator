require 'close_api'
require 'custom_fields'
require 'opportunity_statuses'

# Sets the point of contact for an opp and sequences that contact
class SequenceContactsInCloseJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    @close_api = CloseApi.new
    @fields = CustomFields.new
    @opp_status = OpportunityStatuses.new

    # 1. Sets a point of contact for the opportunity in the 'ready for sequence' status
    set_point_of_contact

    # 2. Subscribe the points of contact in opportunities in the 'read for sequence' status
    subscribe_to_sequence
  end

  def set_point_of_contact
    puts '*** Setting point of contact for opportunities ***'

    contacts = @close_api.all_contacts
    @close_api.all_opportunities.each do |opportunity|
      next unless opportunity['status_id'] == @opp_status.get(:ready_for_sequence)

      lead = @close_api.find_lead(opportunity['lead_id'])
      ready_decision_makers = @close_api.ready_decision_makers(contacts, lead['id'])

      picked_decision_maker = ready_decision_makers.sample(1).last

      if picked_decision_maker.nil?
        msg_slack "No decision maker for #{opportunity['lead_name']}"
        next
      end

      payload = {}
      payload['contact_id'] = picked_decision_maker['id']

      puts "updating: #{opportunity['id']}", payload
      @close_api.update_opportunity(opportunity['id'], payload)
    end
  end

  def subscribe_to_sequence
    # Settings for Creator Sequence
    sequence_payload = {
      sequence_id: 'seq_5N4Ig0PARu1a9py86FHdCE',
      sender_account_id: 'emailacct_xskT1bmpNx4bHJ9AbbvyFs8SRngN9r5kZ2JXWRTnHv9',
      sender_name: 'Leonid Medovyy',
      sender_email: 'leonid@storypro.io'
    }

    @close_api.all_opportunities.each do |opportunity|
      next unless opportunity['status_id'] == @opp_status.get(:ready_for_sequence)

      contact = @close_api.find_contact(opportunity['contact_id'])

      # this is not needed, because the contact should never be set
      # as a decision maker if it has been excluded from a sequence,
      # but we are doing this check just in case to ensure that we are not emailing
      # people we should not email.
      next if contact[@fields.get(:excluded_from_sequence)] == 'Yes'

      contact_email = contact['emails'].reject { |c| c['email'].nil? }.last['email']

      sequence_payload['contact_id'] = contact['id']
      sequence_payload['contact_email'] = contact_email

      @close_api.create_sequence_subscription(sequence_payload)
      puts "emailing: #{opportunity['id']}", sequence_payload

      opportunity_payload = {}
      opportunity_payload['status_id'] = @opp_status.get(:in_sales_sequence)

      puts "updating: #{opportunity['id']}", opportunity_payload
      @close_api.update_opportunity(opportunity['id'], opportunity_payload)
    end
  end

  private

  def msg_slack(msg)
    HTTParty.post(ENV['SLACK_URL'].to_s, body: { text: msg }.to_json)
  end
end
