require 'timers'

module Tasque    
  class Processor
    attr_reader :timers
    
    def initialize
      @timers = Timers::Group.new
      @last_task = false
      @current_task = nil
      @handlers = {}
    end
    
    def add_handler type, &block
      @handlers[type.to_sym] = Proc.new do |task|
        @current_task = task
        task.process
        begin
          task.result = block.call task
        rescue Tasque::TaskError => e
          task.error = {
            task_error: e.task_error
          }
        rescue Exception => e
          task.error = {
            exception: e.message,
            backtrace: e.backtrace
          }
        end
        task.error? ? task.failure : task.complete
        @current_task = nil
      end
      @timers.every(check_interval) do
        begin
          has_task = Tasque::Task.fetch(type) do |task|
            @handlers[type.to_sym].call(task)
          end
        end while has_task
      end
    end

    def start
      shutdown = ->(signo) {
        if @last_task
          unless @current_task.nil?
            @current_task.failure
            @current_task.reprocess
          end
          exit! 
        end
        @last_task = true
      }
      trap("SIGINT", shutdown)
      trap("SIGTERM", shutdown)
      loop do
        break if @last_task
        @timers.wait
      end
    end
    
  private
    def check_interval
      Tasque.config.check_interval
    end
  end
end
