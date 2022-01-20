require 'close_api'
require 'custom_fields'
require 'opportunity_statuses'
require 'lead_statuses'

namespace :cleanup do
  @close_api = CloseApi.new
  @fields = CustomFields.new
  @opp_status = OpportunityStatuses.new
  @lead_status = LeadStatuses.new


  # we are using this to clean up the VIP opportunities pipeline.
  # NOTE: The VIP pipeline is gone, but I am leaving this here for a reference.
  desc "Delete opportunities (based on their status) and mark attached leads as 'bad fit'."
  task opportunities: :environment do

    # throwing in a guard clause to prevent this from running
    return true

    lost_opp_statuses = []
    lost_opp_statuses.push @opp_status.get(:vip_lost)
    lost_opp_statuses.push @opp_status.get(:vip_waiting)
    lost_opp_statuses.push @opp_status.get(:vip_demo)
    lost_opp_statuses.push @opp_status.get(:vip_first_contact)
    lost_opp_statuses.push @opp_status.get(:vip_in_sequence)


    @close_api.all_opportunities.each do |opportunity|
      next unless opportunity['status_id'].in?(lost_opp_statuses)
      next unless opportunity['date_lost'].nil?

      lead_payload = {}
      lead_payload['status_id'] = @lead_status.get(:bad_fit)
      @close_api.update_lead(opportunity['lead_id'], lead_payload)

      @close_api.delete_opportunity opportunity['id']
    end
  end

  # we are using this to move opportunities from 'VIP' to 'Automated' pipelines
  # NOTE: The VIP pipeline is gone, but I am leaving this here for a reference.
  desc "Move oops between pipelines from 'VIP inbox' to the 'Automated inbox'"
  task move_between_pipelines: :environment do

    # throwing in a guard clause to prevent this from running
    return true

    @close_api.all_opportunities.each do |opportunity|
      next unless opportunity['status_id'] == @opp_status.get(:vip_new)

      payload = {}
      payload['status_id'] = @opp_status.get(:inbox)

      @close_api.update_opportunity(opportunity['id'], payload)

      puts opportunity, payload
    end
  end

end
