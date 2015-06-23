require 'rethinkdb'
require 'colorize'

include RethinkDB::Shortcuts

DATABASE = 'ha_elastic_search_development_aws_ip_172_31_38_170'
TABLES   = %w(institution)

namespace :db do
  desc 'Create the database'
  task :db_create do
    r.connect(db: DATABASE) do |conn|
      if r.db_list.run(conn).include? DATABASE
        puts "#{DATABASE} already exists".green
      else
        puts "Creating database #{DATABASE}".yellow
        r.db_create(DATABASE).run(conn)
      end
    end
  end

  desc 'Create the tables'
  task setup: %i(db_create) do
    r.connect(db: DATABASE) do |conn|
      TABLES.each do |table|
        begin
          db_rsp = r.table_create(table).run(conn)
        rescue
          puts db_rsp.red
        end
      end
    end
  end
end

namespace :data do
  desc 'Parse the json data'
  task :parse_data do

  end
end
