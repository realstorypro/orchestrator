# frozen_string_literal: true

# Abstracts access to customer API
class CustomerApi
  def initialize
    @customer_io_api_auth = { "Authorization": "Bearer #{ENV['CUSTOMER_IO_API_KEY']}" }

    @basic_key = Base64.strict_encode64"#{ENV['CUSTOMER_IO_SITE_ID']}:#{ENV['CUSTOMER_IO_TRACKING_API_KEY']}"
    @customer_io_basic_auth = { "Authorization": "Basic #{@basic_key}" }

    @customer_api_base = 'https://beta-api.customer.io/v1/api/'
    @ranked_segments = [
      {
        number: 6,
        name: 'Unsubscribed',
        trumps: true,
        score: 0
      },
      {
        number: 7,
        name: 'Active Subscribers',
        trumps: false,
        score: 0
      },
      {
        number: 12,
        name: 'One Email Open',
        trumps: false,
        score: 0
      },
      {
        number: 8,
        name: 'Two Email Opens',
        trumps: false,
        score: 2
      },
      {
        number: 13,
        name: 'Three Email Opens',
        trumps: false,
        score: 3
      },
      {
        number: 14,
        name: 'Four Email Opens',
        trumps: false,
        score: 4
      }
    ]

    @link_segment = { number: 10, name: 'Link Clicked', trumps: false }
    @not_engaged = { number: 20, name: 'Not Engaged', trumps: false }
  end

  attr_reader :ranked_segments, :link_segment, :not_engaged

  # returns an array of contacts from a segment
  # @param [Integer] segment_id an id of the segment
  # @return [Array] an array of customers
  def get_segment(segment_id)
    # this api endpoint returns a list of customer ids
    # we have to do another call to get the customers themselves
    customer_io_url = URI("#{@customer_api_base}segments/#{segment_id}/membership")

    # gather emails of customers of in the segment
    customers = []
    next_page = 0
    until next_page.blank?
      # do not paginate if we are just getting started
      paginated_customer_io_url = if next_page == 0
                                    URI(customer_io_url)
                                  else
                                    URI("#{customer_io_url}?start=#{next_page}")
                                  end
      customer_rsp = HTTParty.get(paginated_customer_io_url, headers: @customer_io_api_auth)

      customers.append(*get_customers(customer_rsp['ids']))

      next_page = customer_rsp.parsed_response['next']
    end

    customers
  end

  # returns an array of customers based on ids passed
  def get_customers(customer_ids)
    customers = []

    customer_ids.each do |customer_id|
      customer = CioCustomer.find_or_create_by(cio_id: customer_id)
      customer.remote_sync
      customers << customer.data['customer']
    end

    customers
  end

  # decides whether a new segment is superior, inferior or no different
  # from the current segment
  def segment_rank(new_segment_id, active_segment_name)
    current_segment = @ranked_segments.select do |segment|
      segment[:number] == new_segment_id
    end
    current_segment = current_segment.last

    current_segment_index = @ranked_segments.index do |segment|
      segment[:number] == new_segment_id
    end

    active_segment = @ranked_segments.select do |segment|
      segment[:name] == active_segment_name
    end
    active_segment = active_segment.last

    active_segment_index = @ranked_segments.index do |segment|
      segment[:name] == active_segment_name
    end

    if current_segment == active_segment
      'same'
    elsif current_segment[:trumps]
      'superior'
    elsif active_segment_index.nil?
      'superior'
    elsif current_segment_index > active_segment_index
      'superior'
    else
      'inferior'
    end
  end

  # @param segment_name [String] a name stored in Close.IO segment
  def get_segment_score(segment_name)
    segment = @ranked_segments.find { |s| s[:name] == segment_name }
    segment[:score]
  end

  def add_customers_to_segment(segment_id, customer_ids)
    # this uses a tracking api. we'll refactor once we start using it more.
    customer_io_url = "https://track.customer.io/api/v1/segments/#{segment_id}/add_customers"

    data = { ids: customer_ids }

    url = URI(customer_io_url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(url)
    request["content-type"] = 'application/json'

    request["Authorization"] = "Basic #{@basic_key}"

    request.body = data.to_json

    response = http.request(request)
    puts response.read_body
  end
end
