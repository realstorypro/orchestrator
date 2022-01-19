require 'close_api'
require 'custom_fields'
require 'opportunity_statuses'
require 'lead_statuses'

namespace :cleanup do
  @close_api = CloseApi.new
  @fields = CustomFields.new
  @opp_status = OpportunityStatuses.new
  @lead_status = LeadStatuses.new

  desc "TODO"
  task tasks: :environment do
  end

  desc 'Mark opportunities as lost (based on their status).'
  task opportunities: :environment do
  end

end
