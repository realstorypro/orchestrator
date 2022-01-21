namespace :sync do
  desc 'syncs up close.com and customer.io'
  task all: :environment do
    # 1. Sends contacts with 'Needs Nurturing' field set to 'Yes' to customer.io along with 'begin nurture' event
    NurtureCloseContactsInCustomerIoJob.perform_later

    # 2. Syncs up the data from customer.io in close
    SyncCustomerIoSegmentsToCloseJob.perform_later

    # 3. Sets 'yes' in 'Clicked Link' in close.com based on he segment
    # Rake::Task['close:tag_link_clickers'].invoke

    # 4. Sets 'yes' in 'Decision Makers' based on AI decision using job titles
    # Rake::Task['close:tag_decision_makers'].invoke

    # 5. Calculates and sets the 'available decision makers'. The numbers do not include
    # the decision makers with 'Excluded from sequence' field set to 'Yes'
    # Rake::Task['close:calc_decision_makers'].invoke

    # 6. Sets 'yes' in 'Ready for Email' based on AI decision using
    # nurture start date, customer segment and if the link was clicked
    # Rake::Task['close:tag_ready_for_email'].invoke
  end

  desc 'enqueues the sync customer_io segment task'
  task customer_io_segments: :environment do
    SyncCustomerIoSegmentsJob.perform_later
  end
end
