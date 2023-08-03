class Contact < ApplicationRecord
  scope :located_in_us, -> { where("location LIKE ?", "%United States%") }
  scope :us_decision_makers, -> { located_in_us.where(decision_maker: true) }
end
