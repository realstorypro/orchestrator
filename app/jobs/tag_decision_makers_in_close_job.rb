require 'close_api'
require 'custom_fields'
require 'ai'

class TagDecisionMakersInCloseJob < ApplicationJob
  queue_as :default

  # Use AI, and base the decision on the title
  def perform(*args)
    @close_api = CloseApi.new
    @fields = CustomFields.new
    @ai = Ai.new

    msg_slack 'tagging decision makers in close (** Done by AI **)'

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

      # may be useful for debugging in the future
      # puts "#{contact['title']} - #{@ai.decision_maker?(contact['title'])}", '***'
    end
  end

  def msg_slack(msg)
    HTTParty.post(ENV['SLACK_URL'].to_s, body: { text: msg }.to_json)
  end
end
