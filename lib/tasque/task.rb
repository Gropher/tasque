require 'state_machine/core'

module Tasque
  class Task < ActiveRecord::Base
    extend StateMachine::MacroMethods

    MAX_ATTEMPTS=3
    
    self.table_name = :tasque_tasks
    
    serialize :params
    serialize :result
    
    scope :with_task, ->(task) { where(task: task).order priority: :desc }
    scope :minimum_priority, ->(priority) { priority.nil? ? nil : where('priority >= ?', priority) }
    scope :to_process, -> { where status: %w(new reprocessed) }
    scope :with_error, -> { where status: 'error' }
    scope :to_reprocess, -> { with_error.where 'attempts < ?', MAX_ATTEMPTS }
    scope :finished_in, ->(interval) { where('finished_at > ?', interval.ago) }
    
    validates :task, presence: true
    validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :progress, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
    validates :priority, numericality: { only_integer: true }
    
    class << self
      def fetch(task, &block)
        task = nil
        transaction do
          minimum_priority = Tasque.config.minimum_priority
          task = self.with_task(task).to_process.minimum_priority(minimum_priority).lock(true).first
          if task and task.can_pickup?
            task.pickup
          else
            task = nil
          end
        end
        yield(task) if task
        !!task
      end
    
      def monitoring
        {
          queue: Tasque::Task.to_process.count,
          errors: Tasque::Task.with_error.ends_in(1.hour).count
        }
      end
      
      def autoreprocess(reprocess_limit = nil)
        Tasque::Task.to_reprocess.limit(reprocess_limit.to_i).each do |task|
          task.reprocess
        end.count
      end
    end
    
    state_machine :status, initial: :new do
      after_transition on: :pickup do |task|
        task.update_column :worker, Tasque.config.worker
      end
      
      after_transition on: :process do |task|
        task.update_column :started_at, Time.now
      end
      
      after_transition on: :complete do |task|
        task.update_columns progress: 100, processed_at: Time.now
      end
      
      after_transition on: :failure do |task|
        task.update_columns attempts: (task.attempts + 1), result: { error: task.error }, progress: 0.0
      end
      
      after_transition on: :reprocess do |task|
        task.update_columns started_at: nil, result: nil, progress: 0
      end
      
      after_transition do: :notify
      
      
      event :pickup do
        transition [:new, :reprocessed] => :starting
      end
      
      event :process do
        transition :starting => :processing
      end
      
      event :complete do
        transition :processing => :complete
      end
      
      event :failure do
        transition :processing => :error
      end
      
      event :reprocess do
        transition [:processing, :complete, :error] => :reprocessed
      end
      
      event :cancel do
        transition any - [:processing] => :canceled
      end
      
      
      state :processing do
        def progress!(val)
          val = 0   if val < 0
          val = 100 if val > 100
          return if (Time.now.to_i - @last_progress_at.to_i) < Tasque.config.progress_interval || val == @last_progress_val
          self.update_columns progress: val, updated_at: Time.now
          @last_progress_at = Time.now
          @last_progress_val = val
          notify
        end
        
        def error!(task_error)
          raise Tasque::TaskError.new(self, task_error)
        end
      end
      
      state :processing, :error do
        attr_accessor :error

        def error?
          !@error.nil?
        end
      end
    end
    
  private
    def notify      
    rescue Exception => e
      logger.error "Notify error: #{e.message}"
    end
  end
end
