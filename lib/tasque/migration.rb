module Tasque
  class Migration < ActiveRecord::Migration[4.2]
    def self.code
      #<<-END_OF_CODE
        create_table :tasque_tasks do |t|
          t.string :tag
          t.string :task
          t.text :params
          t.text :result
          t.string :worker
          t.integer :priority, :default => 0
          t.integer :attempts, :default => 0
          t.integer :progress, :default => 0
          t.string :status
      
          t.datetime :started_at
          t.datetime :finished_at
      
          t.timestamps
        end
    
        add_index :tasque_tasks, [:status, :task]
        add_index :tasque_tasks, :status
        add_index :tasque_tasks, :tag     
        add_index :tasque_tasks, :task
        add_index :tasque_tasks, :worker
        add_index :tasque_tasks, :priority
        add_index :tasque_tasks, :attempts
      #END_OF_CODE
    end
    
    def change
      eval(self.class.code)
    end
  end
end
