require 'customer_api'
require 'close_api'

namespace :sync do
  @close_api = CloseApi.new
  @customer_api = CustomerApi.new

  desc 'syncs up close.com and customer.io'
  task all: :environment do
    # 1. Sends contacts with 'Needs Nurturing' field set to 'Yes' to customer.io along with 'begin nurture' event
    Rake::Task['close:nurture'].invoke

    # 2. Sets the 'Customer.io segment' based on the customer.io data
    Rake::Task['close:segment_sync'].invoke

    # 3. Sets 'yes' in 'Clicked Link' in close.com based on he segment
    Rake::Task['close:tag_link_clickers'].invoke

    # 4. Sets 'yes' in 'Decision Makers' based on AI decision using job titles
    Rake::Task['close:tag_decision_makers'].invoke

    # 5. Calculates and sets the 'available decision makers'. The numbers do not include
    # the decision makers with 'Excluded from sequence' field set to 'Yes'
    Rake::Task['close:calc_decision_makers'].invoke

    # 6. Sets 'yes' in 'Ready for Email' based on AI decision using
    # nurture start date, customer segment and if the link was clicked
    Rake::Task['close:tag_ready_for_email'].invoke
  end

  desc 'syncs up close.com data'
  task customer: :environment do
    # the call to get_segment retrieves a customer, and caches it in the database.
    _unsubscribed = @customer_api.get_segment(6)
    _active_subscribers = @customer_api.get_segment(7)
  end

  desc 'syncs up close.com data'
  task close: :environment do
    close_contacts = @close_api.all_contacts
    close_contacts.each do |close_contact|
      contact = CloseCustomer.find_or_create_by(close_id: close_contact['id'])
      contact.update(data: close_contact)
    end
  end
end
