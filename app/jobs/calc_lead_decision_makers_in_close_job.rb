require 'close_api'
require 'custom_fields'

class CalcLeadDecisionMakersInCloseJob < ApplicationJob
  queue_as :default

  def perform(*args)
    @close_api = CloseApi.new
    @fields = CustomFields.new

    msg_slack 'calculating the number of available decision makers for close leads'

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

  def msg_slack(msg)
    HTTParty.post(ENV['SLACK_URL'].to_s, body: { text: msg }.to_json)
  end
end
