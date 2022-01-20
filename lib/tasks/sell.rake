namespace :sell do
  desc "gets the sales pipeline ready for sales"
  task prepare: :environment do
    # 1. Sorts the contacts in 'Inbox', 'Needs Contacts', 'Nurturing Contacts' and 'Retry Sequence'
    # Placing them into the 'Needs Contacts', 'Nurturing Contacts' and 'Ready for Sequence'
    Rake::Task['close:sort_opps'].invoke

    
  end

  desc "subscribes people to the sales sequence"
  task do: :environment do
    # 1. Sets a point of contact for the opportunity in the 'ready for sequence' status
    Rake::Task['close:set_contact'].invoke

    # 2. Subscribe the points of contact in opportunities in the 'read for sequence' status
    Rake::Task['close:subscribe_to_sequence'].invoke
  end

end
