class LeadStatuses
  def initialize
    @statuses = {
      potential: 'stat_HTWCvlug8qVffJnpsQaE106YT9Rg0VfLnpFMLNvhprR',
      bad_fit: 'stat_JemNT0UgRV1wWyw2mnAt7SdNb4zUCgv4ksbcv2Rr4l3',
      unknown_tech: 'stat_IFcXnSBllyE2u6xyPwEUQZdGdbDsRYtIWn6FN5lcQjI',
      machine_qualified: 'stat_19ThQzr0KqtyaWQv6CCjzj603581p9clkmK6nYTloFv',
      sub_qualified: 'stat_MvldaXfPttQBD7WJONiGxsAtuSdsF5x6VRiU5QViNOq',
      qualified: 'stat_E28GB5FvYoPxkLI9a2MVvzLKkg1iYvTPsjqN4mnUn7O'
    }
  end

  def get(key)
    @statuses[key]
  end
end
