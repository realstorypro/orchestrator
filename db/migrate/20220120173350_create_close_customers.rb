class CreateCloseCustomers < ActiveRecord::Migration[7.0]
  def change
    create_table :close_customers do |t|
      t.string :close_id
      t.jsonb :data

      t.timestamps
    end
  end
end
