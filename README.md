# tasque

ActiveRecord based task queue. Task processing queue with states, history and priorities. Works with your favorite database.


## Installation

Add this line to your application's `Gemfile`:

    gem 'tasque'

And then execute:

    $ bundle

Or install it manually:

    $ gem install tasque

Then you need to generate initializer and migration:

    $ rails g tasque:install

Don't forget to run migrations: 

    $ rake db:migrate


## Usage

Create a simple task:

    Tasque::Task.create! task: 'test', params: { text: 'This is the test!' }

Or a task with priority:

    Tasque::Task.create! task: 'test', priority: 9000, params: { text: 'I will be processed first!!!' }

Or add a tag to find this task easily: 
  
    Tasque::Task.create! task: 'test', tag: 'user_123', params: { text: 'This task is property of User #123!' }

Now to process the task:

    # create task processor
    processor = Tasque::Processor.new

    # register a handler for test tasks
    processor.add_handler('test') do |task|
      puts "Got task ##{task.id}. Task says: '#{task.params['text']}'"
      task.complete!
      { log: 'got task, printed text' } # returning task result
    end

    # start processor and wait
    processor.start
    
    
### Using with Insque

Tasque can send task and worker state updates via [Insque](https://github.com/Gropher/insque). 

To enable this featute uncomment following lines in your tasque initializer: 

    # Send task state updates and progress notifications via Insque
    config.notify = true

    # Send worker heartbeat via Insque
    config.heartbeat = true
    config.heartbeat_interval = 10 # seconds
    

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
