class CreateJobs < ActiveRecord::Migration
  def self.up
    create_table :jobs do |t|
      t.string :path
      t.string :batch_id

      t.text :args
      t.text :result
      t.datetime :started_at
      t.datetime :cancelled_at
      t.datetime :completed_at
      t.string :status

      t.string :error_class
      t.string :error_message
      t.text :error_backtrace

      t.string :employee_host
      t.integer :employee_pid

      t.timestamps
    end

    add_index :jobs, :path
    add_index :jobs, :batch_id
    add_index :jobs, :status

    postgres = (ActiveRecord::Base.connection.adapter_name == 'PostgreSQL')

    ['started_at', 'cancelled_at', 'completed_at'].each do |field|
      execute "CREATE INDEX IF NOT EXISTS jobs_#{field}_is_null ON jobs (#{field})" + (postgres ? " WHERE #{field} IS NULL" : '')
    end
  end

  def self.down
    drop_table :jobs
  end
end
