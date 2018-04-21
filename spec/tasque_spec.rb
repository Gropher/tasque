require 'json'
require 'active_support/all'
require 'active_record'
require 'tasque'
require 'insque'

RSpec.describe 'tasque' do
  before(:all) do
    system "docker swarm init || true"
    system "docker stack deploy -c insque.local.yml insque"
    sleep 10
    Insque.debug = false
    Insque.sender = 'myapp'
    Insque.redis_config = { host: 'localhost', port: 63790 }
    Thread.abort_on_exception=true
    ActiveRecord::Base.establish_connection(
      :adapter   => 'sqlite3',
      :database  => 'db/test.db'
    )
    ActiveRecord::Base.connection.execute('create table tasque_tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, tag TEXT, task TEXT, params TEXT, result TEXT, worker TEXT, status TEXT DEFAULT "new", attempts INTEGER DEFAULT 0, progress INTEGER DEFAULT 0, priority INTEGER DEFAULT 0, started_at DATETIME, finished_at DATETIME, updated_at DATETIME, created_at DATETIME);')
  end

  after(:all) do
    system "docker stack rm insque"
    ActiveRecord::Base.connection.execute('drop table tasque_tasks;')
  end

  before(:each) do
    Insque.redis.flushall
    Tasque::Task.delete_all
    Tasque.configure do |config|
      config.worker = 'myworker'
      config.check_interval = 1 # seconds
      config.progress_interval = 1 # seconds
      config.minimum_priority = nil
      config.notify = false
      config.heartbeat = false
      config.heartbeat_interval = 1
    end
  end

  it 'creates a task' do
    Tasque::Task.create! task: 'test', params: { text: 'This is the test!' }
    expect(Tasque::Task.count).to eq(1)
  end

  it 'processes a task' do
    task = Tasque::Task.create! task: 'test', params: { text: 'This is the test!' }
    processor_thread = Thread.new do
      processor = Tasque::Processor.new
      processor.add_handler('test') do |t|
        t.complete!
        { log: 'completed task' } 
      end
      processor.start
    end
    sleep 2
    processor_thread.exit
    task.reload
    expect(task.status).to eq('complete')
    expect(task.progress).to eq(100)
  end 

  it 'uses minimum priority' do
    Tasque.config.minimum_priority = 10
    task1 = Tasque::Task.create! task: 'test', priority: 1, params: { text: 'This is low priority!' }
    task2 = Tasque::Task.create! task: 'test', priority: 100, params: { text: 'This is high priority!' }
    processor_thread = Thread.new do
      processor = Tasque::Processor.new
      processor.add_handler('test') do |t|
        t.complete!
        { log: 'completed task' } 
      end
      processor.start
    end
    sleep 2
    processor_thread.exit
    task1.reload
    task2.reload
    expect(task1.status).to eq('new')
    expect(task2.status).to eq('complete')
  end 

  it 'reports progress' do
    task = Tasque::Task.create! task: 'test', params: { text: 'This is the test!' }
    processor_thread = Thread.new do
      processor = Tasque::Processor.new
      processor.add_handler('test') do |t|
        t.progress! 50
        sleep 2
        t.complete!
        { log: 'completed task' } 
      end
      processor.start
    end
    sleep 2
    task.reload
    expect(task.status).to eq('processing')
    expect(task.progress).to eq(50)
    sleep 2
    processor_thread.exit
    task.reload
    expect(task.status).to eq('complete')
    expect(task.progress).to eq(100)
  end

  it 'reports errors' do
    task = Tasque::Task.create! task: 'test', params: { text: 'This is the test!' }
    processor_thread = Thread.new do
      processor = Tasque::Processor.new
      processor.add_handler('test') do |t|
        raise 'Test Exception'
        { log: 'completed task' } 
      end
      processor.start
    end
    sleep 2
    processor_thread.exit
    task.reload
    expect(task.status).to eq('error')
    expect(task.result['error']['exception']).to eq('Test Exception')
  end

  it 'uses insque notifications' do
    Tasque.config.notify = true
    janitor = Thread.new { Insque.janitor }
    sleep 1
    Tasque::Task.create! task: 'test', params: { text: 'This is the test!' }
    processor_thread = Thread.new do
      processor = Tasque::Processor.new
      processor.add_handler('test') do |t|
        t.complete!
        { log: 'completed task' } 
      end
      processor.start
    end
    sleep 2
    expect(Insque.redis.llen '{insque}inbox_myapp').to eq(3)
    processor_thread.exit
    janitor.exit
  end

  it 'uses heartbeat' do
    Tasque.config.heartbeat = true
    janitor = Thread.new { Insque.janitor }
    sleep 1
    processor_thread = Thread.new do
      processor = Tasque::Processor.new
      processor.start
    end
    sleep 4
    expect(Insque.redis.llen '{insque}inbox_myapp').to eq(3)
    processor_thread.exit
    janitor.exit
  end
end
