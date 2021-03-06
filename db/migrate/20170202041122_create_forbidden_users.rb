class CreateForbiddenUsers < ActiveRecord::Migration[4.2]
  def change
    create_table :forbidden_users do |t|
      t.string :screen_name, null: false
      t.bigint :uid,         null: true

      t.timestamps null: false

      t.index :screen_name, unique: true
      t.index :created_at
    end
  end
end
