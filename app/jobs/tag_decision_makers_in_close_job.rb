require 'close_api'
require 'custom_fields'
require 'ai'

# Tags decision making contacts
class TagDecisionMakersInCloseJob < ApplicationJob
  queue_as :default

  # Use AI, and base the decision on the title
  def perform(*_args)
    @ai = Ai.new
    @ai.train_decision_makers

    Contact.all.each do |contact|
      next if contact.title.blank?

      contact.update(decision_maker: true) if @ai.decision_maker?(contact.title)

      # may be useful for debugging in the future
      puts "#{contact.title} - #{@ai.decision_maker?(contact.title)}", '***'
    end
  end
end
