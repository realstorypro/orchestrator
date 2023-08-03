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

  task migrate_local: :environment do
    CioCustomer.all.each do |cio_customer|
      next unless cio_customer.data["customer"]

      begin
      Contact.create(
        email: cio_customer.data["customer"]["attributes"]["email"],
        first_name: cio_customer.data["customer"]["attributes"]["first_name"],
        last_name: cio_customer.data["customer"]["attributes"]["last_name"],
        title: cio_customer.data["customer"]["attributes"]["title"],
        url: cio_customer.data["customer"]["attributes"]["url"],
        company: cio_customer.data["customer"]["attributes"]["company"],
        location: cio_customer.data["customer"]["attributes"]["location"],
        timezone: cio_customer.data["customer"]["attributes"]["timezone"],
        source: cio_customer.data["customer"]["attributes"]["source"],
        created_at: cio_customer.data["customer"]["attributes"]["created_at"],

      )
      end
    rescue ActiveRecord::RecordNotUnique => e
      puts "Skipping due to duplicate email: #{e.message}"
    end
  end

end
