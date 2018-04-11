require 'rails/generators'
require 'rails/generators/migration'

module Tasque
  class InstallGenerator < ::Rails::Generators::Base
    include Rails::Generators::Migration

    desc 'Create a sample Tasque initializer and migration'
    source_root File.expand_path('../templates', __FILE__)

    def self.next_migration_number(path)
      unless @prev_migration_nr
        @prev_migration_nr = Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
      else
        @prev_migration_nr += 1
      end
      @prev_migration_nr.to_s
    end

    def create_initializer
      template 'tasque.erb', 'config/initializers/tasque.rb'
      migration_template "create_tasque_tasks.erb", "db/migrate/create_tasque_tasks.rb"
    end
  end
end
