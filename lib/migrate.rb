class CreateJobs < ActiveRecord::Migration
  def self.up
    create_table :jobs do |t|
      t.string :path
      t.text :options
      t.text :result
      t.datetime :started_at
      t.datetime :completed_at
      t.string :status
      t.string :error_message
      t.text :error_backtrace

      t.timestamps
    end

    add_index :jobs, :path
    add_index :jobs, :status
  end

  def self.down
    drop_table :jobs
  end
end
