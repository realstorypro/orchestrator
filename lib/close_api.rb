require 'custom_fields'

class CloseApi
  def initialize
    @fields = CustomFields.new
    @close_api_base = "https://#{ENV['CLOSE_API_KEY']}:@api.close.com/api/v1/"
  end

  def search(json_file)
    search_config = JSON.parse(File.read("./lib/tasks/search/#{json_file}"))
    contacts = []

    more_results = true
    while more_results
      close_rsp = HTTParty.post(URI("#{@close_api_base}data/search/"),
                                {
                                  headers: { 'Content-Type' => 'application/json' },
                                  body: search_config.to_json
                                })
      contacts.append(*close_rsp.parsed_response['data'])
      search_config['cursor'] = close_rsp.parsed_response['cursor']
      more_results = false if close_rsp.parsed_response['cursor'].nil?
    end

    contacts
  end

  # finds contact in a contact list based on the email address
  def find_in_contacts(contacts, search_email)
    found = false

    # contacts have multiple emails, we go through all of them looking for
    # a match
    contacts.each do |contact|
      contact['emails'].each do |email|
        email_address = email['email']

        # finding the contact
        next unless search_email == email_address

        found = contact
      end
    end
    found
  end


  # fetches all tasks
  def all_tasks
    all('task')
  end

  # creates a new task
  def create_task(payload)
    create('task', payload)
  end


  # updates an existing task
  def update_task(id, payload)
    update('task', id, payload)
  end

  ######  **** Sequences **** ######
  # fetches all sequences
  def all_sequence
    all('sequence')
  end

  def create_sequence_subscription(payload)
    create('sequence_subscription', payload)
  end

  # finds all sequence subscriptions
  # pass in the sequence id
  def all_sequence_subscriptions(id)
    all 'sequence_subscription', 'sequence_id': id
  end

  ######  **** Leads **** ######

  # fetch a singular lead
  def find_lead(id)
    find('lead', id)
  end

  # fetches all leads
  def all_leads
    all('lead')
  end

  # updates existing lead
  def update_lead(id, payload)
    update('lead', id, payload)
  end

  # Fetches the ready decision makers for the lead
  # @param contacts [Array] the contacts array
  # @param lead_id [Integer] the id of the lead we are looking up
  def ready_decision_makers(contacts, lead_id)
    lead_contacts = contacts.select { |c| c['lead_id'] == lead_id }
    lead_contacts = lead_contacts.select { |c| c[@fields.get(:decision_maker)] == 'Yes' }
    lead_contacts = lead_contacts.reject { |c| c[@fields.get(:excluded_from_sequence)] == 'Yes' }
    lead_contacts.select { |c| c[@fields.get(:ready_for_email)] == 'Yes' }
  end

  ######  **** Contacts **** ######

  # fetches a singular contact
  def find_contact(id)
    find('contact', id)
  end

  # fetches all contacts
  def all_contacts
    all('contact')
  end

  # updates existing contact
  def update_contact(id, payload)
    update('contact', id, payload)
  end

  ######  **** Opportunities **** ######

  # fetches all opportunities
  def all_opportunities
    all('opportunity')
  end

  # create new opportunity
  # @param payload [Hash] the opporutnity payload
  def create_opportunity(payload)
    create('opportunity', payload)
  end

  # update an existing opportunity
  # @param opportunity_id [Integer] the id of the opportunity
  # @param payload [Hash] the payload containing updated fields
  def update_opportunity(opportunity_id, payload)
    update('opportunity', opportunity_id, payload)
  end

  # Finds all opportunities for a given lead
  # @param lead_id [Integer] the id of the lead
  def all_lead_opportunities(lead_id)
    all 'opportunity', 'lead_id': lead_id
  end

  # Takes care of transferring opportunities from one status to another
  # @param from_status [String] status from which we're transferring opps.
  # @param to_status [String] status to which we're transferring opps.
  # @return [Boolean] returns true once everything is done
  def transfer_opportunities(from_status, to_status)
    opportunities = all_opportunities
    opportunities.each do |opportunity|
      next unless opportunity['status_id'] == from_status

      payload = {
        status_id: to_status
      }
      update_opportunity opportunity['id'], payload
    end

    true
  end



  private

  # Retrieves a singular item of a particular find
  # @param kind [String] a kind of an item (i.e lead or contact)
  # @param id [Integer] an id of an item we're retrieving
  def find(kind, id)
    HTTParty.get(URI(@close_api_base + "#{kind}/#{id}/"))
  end

  # creates an item
  # the payload must be passed as a hash
  def create(kind, payload)
    HTTParty.post(URI("#{@close_api_base}#{kind}/"),
                  {
                    headers: { 'Content-Type' => 'application/json' },
                    body: payload.to_json
                  })
  end

  # updates singular item
  # the payload must be passed as hash
  def update(kind, id, payload)
    HTTParty.put(URI("#{@close_api_base}#{kind}/#{id}/"),
                 {
                   headers: { 'Content-Type' => 'application/json' },
                   body: payload.to_json
                 })
  end

  # fetches all of a kind
  # @param [Hash] keys - additional parameters to be used in url string
  def all(kind, keys = {})
    url_string = ''

    unless keys.empty?
      keys.each do |key, value|
        url_string.concat "#{key}=#{value}&"
      end
    end

    url_string.concat '_skip'

    has_more_response = true
    response_offset = 0

    response = []
    until has_more_response.blank?
      close_rsp = HTTParty.get(URI(@close_api_base + "#{kind}/?#{url_string}=#{response_offset}"))
      response.append(*close_rsp.parsed_response['data'])
      has_more_response = close_rsp.parsed_response['has_more']

      # we're iterating 100 responses at a time.
      response_offset += 100
    end

    response
  end
end
