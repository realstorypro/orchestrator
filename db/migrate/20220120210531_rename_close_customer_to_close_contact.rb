class RenameCloseCustomerToCloseContact < ActiveRecord::Migration[7.0]
  def change
    rename_table :close_customers, :close_contacts
  end
end
