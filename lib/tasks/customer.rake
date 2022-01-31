namespace :customer do
  desc 'enqueues the sync customer_io segments to the database'
  task sync: :environment do
    SyncCustomerIoSegmentsJob.perform_later
  end
end
