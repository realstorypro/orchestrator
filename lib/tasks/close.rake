# frozen_string_literal: true

namespace :close do
  desc 'syncs up close.com and customer.io'
  task sync: :environment do
    # 1. Sends contacts with 'Needs Nurturing' field set to 'Yes' to customer.io along with 'begin nurture' event
    NurtureCloseContactsInCustomerIoJob.perform_later

    # 2. Syncs up the data from customer.io in close
    SyncCustomerIoSegmentsToCloseJob.perform_later

    # 3. Sets 'Yes' in 'Clicked Link' in close.com based on he segment
    TagLinkClickersInCloseJob.perform_later

    # 4. Sets 'Yes' in 'Not Engaged' in close.com based on he segment
    TagNotEngagedInCloseJob.perform_later

    # 5. Sets 'Yes' in 'Decision Makers' based on AI decision using job titles
    TagDecisionMakersInCloseJob.perform_later

    # 6. Calculates and sets the 'Available Decision Makers'. The numbers do not include
    # the decision makers with 'Excluded from sequence' field set to 'Yes'
    CalcLeadDecisionMakersInCloseJob.perform_later

    # 7. Sets 'yes' in 'Ready for Email' based on AI decision using
    # nurture start date, customer segment and if the link was clicked
    TagReadyForEmailInCloseJob.perform_later

    # 8. Sorts the contacts in 'Inbox', 'Needs Contacts', 'Nurturing Contacts' and 'Retry Sequence'
    SortOpportunitiesInCloseJob.perform_later

    # 9. Subscribes contacts to sequence for opportunities in 'Ready For Sequence' status
    SequenceContactsInCloseJob.perform_later
  end
end
