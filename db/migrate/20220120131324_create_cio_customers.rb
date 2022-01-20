class CreateCioCustomers < ActiveRecord::Migration[7.0]
  def change
    create_table :cio_customers do |t|
      t.jsonb :data

      t.timestamps
    end
  end
end
