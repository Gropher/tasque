module Tasque
  class TaskCancel < Exception
    attr_reader :task
  
    def initialize(task)
      @task = task
    end
  end
end

