class AddDecisionMakerToContacts < ActiveRecord::Migration[7.0]
  def change
    add_column :contacts, :decision_maker, :boolean, default: false
  end
end
