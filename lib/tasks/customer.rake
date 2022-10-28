require 'customer_api'

namespace :customer do
  desc 'enqueues the sync customer_io segments to the database'
  task sync: :environment do
    SyncCustomerIoSegmentsJob.perform_later
  end

  desc 'warms up the customer.io subscribers'
  task :warmup, [:number] => :environment do |_t, args|
    @customer_api = CustomerApi.new

    warmup_number = args[:number].blank? ? 10 : args[:number]

    warmup_segment_id = 30
    cold_segment_id = 31

    cold_segment = @customer_api.get_segment(cold_segment_id)
    cleaned_cold_segment = cold_segment.select { |s| s.present? }

    sample = cleaned_cold_segment.shuffle.sample(warmup_number.to_i)
    customers_to_warmup = sample.collect { |c| c['id'] unless c.nil? || c['id'] == 'nil' }

    @customer_api.add_customers_to_segment(warmup_segment_id, customers_to_warmup)

    puts "Warming up #{warmup_number} subscribers"
  end
end
