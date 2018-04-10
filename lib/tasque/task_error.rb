module Tasque
  class TaskError < Exception
    attr_reader :task
    attr_reader :task_error
  
    def initialize(task, task_error)
      @task = task
      @task_error = task_error
    end
  end
end
