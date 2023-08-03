class CreateContactus < ActiveRecord::Migration[7.0]
  def change
    create_table :contacts do |t|
      t.string :email
      t.string :first_name
      t.string :last_name
      t.string :title
      t.string :url
      t.string :company
      t.string :location
      t.string :timezone
      t.string :source

      t.timestamps
    end

    add_index :contacts, :email, unique: true
  end
end
