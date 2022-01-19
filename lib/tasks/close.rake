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

  desc "Sends contacts with 'Needs Nurturing' field set to 'Yes' to customer.io"
  task :nurture, [:number] => :environment do |_t, _args|
    msg_slack 'preparing to nurture close.com contacts in customer.io'
    close_contacts = @close_api.search('nurture.json')

    $customerio = Customerio::Client.new(ENV['CUSTOMER_IO_SITE_ID'], ENV['CUSTOMER_IO_KEY'])

    close_contacts.each do |contact|
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
        puts '----'

        $customerio.identify(
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

        $customerio.track(the_email, 'begin nurture')
      end
    end
  end

  desc 'syncs the segments from customer.io to close.com'
  task :segment_sync, [:number] => :environment do |_t, _args|
    # update close contacts
    def update_close_contacts(close_contacts, customer_contacts, customer_segment)
      customer_contacts.each do |customer_contact|
        customer_email = customer_contact['attributes']['email']
        customer_created_at = Time.at(
          customer_contact['timestamps']['cio_id']
        ).strftime('%m/%d/%Y')

        close_contact = @close_api.find_in_contacts(close_contacts, customer_email)

        next unless close_contact

        ### CUSTOM FIELDS
        # Customer.Io Segment - custom.cf_Rp7Z0tH5Jt2CeVU3uv1q02cRHfoIAl1ub8rDR9AiYHW
        # Needs Nurturing - custom.cf_N5Hnzwt4EMcuwGVZkBZuomSVBAMpo07Hzert2hG8QD1
        # Nurture Start Date - custom.cf_xhT1KuDwk1IzhNbtzkKoY9VocISAA29QqPkfmffJPFY

        # we only want to sync if the new segment is of a higher rank
        rank = @customer_api.segment_rank(customer_segment[:number], close_contact['custom.cf_Rp7Z0tH5Jt2CeVU3uv1q02cRHfoIAl1ub8rDR9AiYHW'])

        # we don't want to update anything unless the rank has gone up
        next unless rank == 'superior'

        lead = @close_api.find_lead(close_contact['lead_id'])
        lead_status = lead['status_label']

        if customer_segment[:add_task] && lead_status != 'Bad Fit'
          msg_slack "#{customer_segment[:task_message]} #{close_contact['display_name']} (#{close_contact['title']}) [#{lead_status}]"

          task_payload = {
            "_type": 'lead',
            "lead_id": close_contact['lead_id'],
            "assigned_to": 'user_iGM2Ik3TrAjWvGy01ET3vNkdd6nRyTFEw0Qi873OTkf',
            "text": "#{customer_segment[:task_message]} #{close_contact['display_name']} (#{close_contact['title']}) [#{lead_status}]",
            "date": (Date.today).strftime('%F'),
            "is_complete": false
          }

          @close_api.create_task(task_payload)
        end

        contact_payload = {
          'custom.cf_Rp7Z0tH5Jt2CeVU3uv1q02cRHfoIAl1ub8rDR9AiYHW': customer_segment[:name],
          'custom.cf_N5Hnzwt4EMcuwGVZkBZuomSVBAMpo07Hzert2hG8QD1': customer_segment[:needs_nurturing],
          'custom.cf_xhT1KuDwk1IzhNbtzkKoY9VocISAA29QqPkfmffJPFY': customer_created_at
        }

        response = @close_api.update_contact(close_contact['id'], contact_payload)

        puts close_contact, customer_created_at, response, '------'

      end
    end

    msg_slack 'preparing to sync customer.io segments to close.com'

    @customer_api.segments.each do |segment|
      customer_contacts = @customer_api.get_segment(segment[:number])
      close_contacts = @close_api.all_contacts
      update_close_contacts(close_contacts, customer_contacts, segment)
    end
  end

  # Base this on the Link Clicker Segment
  desc 'tag customers that have clicked a link'
  task :tag_link_clickers => :environment do
    customer_contacts = @customer_api.get_segment(@customer_api.link_segment[:number])
    close_contacts = @close_api.all_contacts

    customer_contacts.each do |customer_contact|
      customer_email = customer_contact['attributes']['email']

      close_contact = @close_api.find_in_contacts(close_contacts, customer_email)
      next unless close_contact

      contact_payload = {}
      contact_payload[@fields.get(:clicked_link)] = 'Yes'

      response = @close_api.update_contact(close_contact['id'], contact_payload)
      puts response
    end
  end

  # Use AI, and base it on the Title
  desc 'tag decision makers'
  task :tag_decision_makers => :environment do

     @ai.train_decision_makers
     contacts = @close_api.all_contacts
     contacts.each do |contact|
       next if contact['title'].blank?

       next unless contact[@fields.get(:decision_maker)].blank?

       contact_payload = {}
       contact_payload[@fields.get(:decision_maker)] = if @ai.decision_maker? contact['title']
                                                         'Yes'
                                                       else
                                                         'No'
                                                       end

       @close_api.update_contact(contact['id'], contact_payload)

       puts "#{contact['title']} - #{@ai.decision_maker?(contact['title'])}", '***'
     end
   end

  desc 'calculate available decision makers per lead'
  task :calc_decision_makers => :environment do
    leads = @close_api.all_leads
    contacts = @close_api.all_contacts

    leads.each do |lead|
      # find all lead contacts
      lead_contacts = contacts.select do |contact|
        contact['lead_id'] == lead['id']
      end

      # filter out the decision makers
      decision_makers = lead_contacts.select do |contact|
        next if contact[@fields.get(:decision_maker)].nil?

        contact[@fields.get(:decision_maker)].include? 'Yes'
      end

      # remove decision makers excluded from sequence
      available_decision_makers = decision_makers.reject do |contact|
        contact[@fields.get(:excluded_from_sequence)] == 'Yes'
      end

      # create the lead payload
      payload = {}
      payload[@fields.get(:available_decision_makers)] = available_decision_makers.count

      # update the lead
      @close_api.update_lead(lead['id'], payload)
    end
  end

  desc 'tag contacts ready for email'
  task :tag_ready_for_email do
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

      puts contact, "****"
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
        @close_api.update_opportunity opportunity['id'],
                                      "status_id": 'stat_EZlDvFrb9F9jj93Okls3fBQAWGTS2LcrMoeKmE4kqRR'

        # 12. set the contact to the do not sequence
        @close_api.update_contact contact['id'],
                                  "custom.cf_iuK23d7LKjVFuR9z52ddWRHEjCkkHZ23xCRzLvGIP83": 'Yes'

        puts opportunity, subscription, '****'
      end
      puts sequence['name'], subscriptions.count, '----'
    end
  end

  desc 'sorts contacts in the retry sequence stage'
  task :sort_retries do
    puts '*** Sorting Retries Opportunity Stage ***'

    contacts = @close_api.all_contacts
    @close_api.all_opportunities.each do |opportunity|
      next unless opportunity['status_id'] == @opp_status.get(:retry_sequence)

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

  desc 'plucks nurtured opportunities'
  task :pluck_nurtured do
    puts '*** Plucking Nurtured Opportunities ***'

    contacts = @close_api.all_contacts
    @close_api.all_opportunities.each do |opportunity|
      next unless opportunity['status_id'] == @opp_status.get(:nurturing_contacts)

      lead = @close_api.find_lead(opportunity['lead_id'])
      ready_decision_makers = @close_api.ready_decision_makers(contacts, lead['id'])

      next if ready_decision_makers.empty?

      payload = {}
      payload['status_id'] = @opp_status.get(:ready_for_sequence)

      puts "updating: #{opportunity['id']}", payload
      @close_api.update_opportunity(opportunity['id'], payload)
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

    # sequence_payload['contact_id'] = 'cont_CcGnPF1ua7rIyRTYCjkt0pgeshW6TjS6gWcRZSzgVih'
    # sequence_payload['contact_email'] = 'leonid@storypro.io'

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

  desc 'get a sender account it'
  task :sender_id do

  end

  def msg_slack(msg)
    HTTParty.post(ENV['SLACK_URL'].to_s, body: { text: msg }.to_json)
  end
end
