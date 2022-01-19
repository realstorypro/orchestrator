require 'csv'
require 'classifier-reborn'

class Ai
  def initialize
    @decision_makers = 'decision_makers.csv'
    @decision_classifier = ClassifierReborn::Bayes.new 'Decision Maker', 'Regular'

    @sequence_training = 'sequence_training.csv'
    @sequence_inputs = []
    @sequence_outputs = []
    setup_sequence_dictionary
  end

  def train_decision_makers
    training_data = File.read("./lib/training/#{@decision_makers}")
    parsed_data = CSV.parse(training_data, headers: true)
    parsed_data.each do |row|
      case row['decisionmaker']
      when 'x'
        @decision_classifier.train('Decision Maker', row['title'])
      when 'o'
        @decision_classifier.train('Regular', row['title'])
      end
    end
  end

  def setup_sequence_dictionary
    training_data = File.read("./lib/training/#{@sequence_training}")
    parsed_data = CSV.parse(training_data, headers: true)

    parsed_data.each do |row|
      @sequence_inputs.push ([row['weeks old'].to_i,
                              row['segment'].to_i,
                              yes_no(row['clicked_link']),
                              yes_no(row['visited_website']),
                              yes_no(row['visited pricing page'])])

      case row['sequence']
      when 'x'
        @sequence_outputs.push 1
      when 'o'
        @sequence_outputs.push 0
      end
    end
  end

  # Determines if the job title belongs to a decison maker
  # @param title [String] the job title, used to determine if the person is a decision maker
  # @return [Boolean] returns true if the title belongs to a decision maker
  def decision_maker?(title)
    return true if @decision_classifier.classify(title) == 'Decision maker'

    false
  end

  # Determines if the email should be sent or not
  # @param weeks_old [Integer] how long ago the nurture started. minimum 1 week
  # @param segment [Integer] what segment a person belongs to (2,3,4) email opens
  # @param clicked_link [Integer] whether a link has been clicked in an email (1 for true, and 0 for false)
  # @param visited_website [Integer] whether a website has been visited (1 for true, and 0 for false)
  # @param visited_pricing [Integer] whether a pricing page has been visited (1 for true, and 0 for false)
  def send_email?(weeks_old, segment, clicked_link, visited_website, visited_pricing)
    search_array = [weeks_old, segment, clicked_link, visited_website, visited_pricing]
    search_index = @sequence_inputs.find_index(search_array)

    return true if @sequence_outputs[search_index] == 1

    false
  end

  private

  # a helper method that converts yes or no to an int
  def yes_no(val)
    if val == 'yes'
      1.to_i
    else
      0.to_i
    end
  end

end
