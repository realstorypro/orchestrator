require 'close_api'
require 'custom_fields'

# Populates 'Nurture Start Month' for contacts
class PopulateNurtureStartMonthJob < ApplicationJob
  queue_as :default

  def perform(*args)
    @close_api = CloseApi.new
    @fields = CustomFields.new

    # 1. Go through contacts without 'Nurture Start Month' and set it
    set_nurture_start_month
  end

  def set_nurture_start_month
    msg_slack "Setting 'Nurture Start Month' for contacts"
    contacts = @close_api.all_contacts
    contacts.each do |contact|
      nurture_start_date = contact[@fields.get(:nurture_start_date)]
      nurture_start_month = contact[@fields.get(:nurture_start_month)]

      # skip tagging if we dont have the
      # nurture start date
      next if nurture_start_date.nil?

      # we dont want to do this if nurture_start_month isn't empty
      # for performance reasons
      next unless nurture_start_month.nil?

      month_in_words = DateTime.parse(nurture_start_date).strftime("%B")

      contact_payload = {}
      contact_payload[@fields.get(:nurture_start_month)] = month_in_words

      @close_api.update_contact contact["id"], contact_payload
    end
  end


  private

  def msg_slack(msg)
    HTTParty.post(ENV['SLACK_URL'].to_s, body: { text: msg }.to_json)
  end

end
