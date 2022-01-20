class AddCioIdToCioCustomers < ActiveRecord::Migration[7.0]
  def change
    add_column :cio_customers, :cio_id, :string
  end
end
