# frozen_string_literal: true

require 'close_api'
require 'custom_fields'
require 'customer_api'
require 'opportunity_statuses'
require 'lead_statuses'

require 'ai'

require 'json'
require 'csv'

namespace :close do
  @close_api = CloseApi.new
  @customer_api = CustomerApi.new
  @fields = CustomFields.new
  @opp_status = OpportunityStatuses.new
  @lead_status = LeadStatuses.new
  @ai = Ai.new

  desc "sorts opportunities between 'Needs Contacts', 'Nurturing Contacts', and 'Ready for Sequence'"
  task :sort_opps do
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

  desc "sorts contacts in the 'In Sales Sequence' stage"
  task :sort_in_sales do

    # 0. Lets get all sequence subscriptions
    # sales_sequence = 'seq_5N4Ig0PARu1a9py86FHdCE'
    # sequences = @close_api.all_sequence_subscriptions(sales_sequence)

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

        # 6.1 We are only looking at sequences older then 4 and less then 10 days
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


  desc 'move opp to retry if seq is completed'
  task :retry_ops, [:number] => :environment do
    # 1. get a list of all sequences
    sequences = @close_api.all_sequence

    # 2. run a sequence loop
    sequences.each do |sequence|
      next unless sequence['status'] == 'active'

      subscriptions = @close_api.all_sequence_subscriptions(sequence['id'])

      subscriptions.each do |subscription|
        # 3. go through all the finished and paused subscriptions
        next unless subscription['status'].in? %w[finished paused]

        # 4. fetch the associated contact
        contact = @close_api.find_contact(subscription['contact_id'])

        # 5. check if the contact is on the do not sequence list
        next if contact['custom.cf_iuK23d7LKjVFuR9z52ddWRHEjCkkHZ23xCRzLvGIP83'] == 'Yes'

        lead = @close_api.find_lead(contact['lead_id'])
        opportunities = @close_api.all_lead_opportunities(contact['lead_id'])

        # 6. we're only assigning one opportunity per lead, and thus
        # are only looking at the last opportunity
        opportunity = opportunities.last

        # 7. Move on if the opportunity does not exist
        next if opportunity.nil?

        # 8. we only want to perform the action on active opportunities
        next unless opportunity['status_type'] == 'active'

        # TODO: Redo this use the status ids instead
        # 9. don't do anything if the opportunity is in the 'in-progress' stages
        next if opportunity['status_display_name'].in? ['Demo Completed', 'Proposal Sent', 'Waiting']

        # 10. don't do anything if sequence was updated less then 5 days ago
        date_updated = DateTime.parse(opportunity['date_updated'])
        date_difference = date_updated.step(Date.today).count

        next if date_difference < 5

        # 11. update opportunity status to 'retry' stage
        # @close_api.update_opportunity opportunity['id'],
        #                               "status_id": 'stat_EZlDvFrb9F9jj93Okls3fBQAWGTS2LcrMoeKmE4kqRR'

        # 12. set the contact to the do not sequence
        # @close_api.update_contact contact['id'],
        #                           "custom.cf_iuK23d7LKjVFuR9z52ddWRHEjCkkHZ23xCRzLvGIP83": 'Yes'

        puts opportunity, subscription, '****'
      end
      puts sequence['name'], subscriptions.count, '----'
    end
  end

  desc "sets a point of contact for the opportunity in status 'ready for sequence'"
  task :set_contact do
    puts '*** Setting Point of Contact for Opportunities ***'

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

  desc 'subscribe to sequence for events in the ready stage'
  task :subscribe_to_sequence do

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


  def msg_slack(msg)
    HTTParty.post(ENV['SLACK_URL'].to_s, body: { text: msg }.to_json)
  end
end
