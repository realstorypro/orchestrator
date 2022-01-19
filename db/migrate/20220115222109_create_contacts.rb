class CreateContacts < ActiveRecord::Migration[7.0]
  def change
    create_table :contacts do |t|
      t.string :close_id
      t.string :customer_id
      t.jsonb :close_data
      t.jsonb :customer_data

      t.timestamps
    end
  end
end
