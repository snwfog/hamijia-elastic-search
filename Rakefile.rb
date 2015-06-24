require 'rethinkdb'
require 'colorize'
require 'algoliasearch'
require 'pry-byebug'

include RethinkDB::Shortcuts

DATABASE = 'ha_elastic_search_development_aws_ip_172_31_38_170'
TABLES   = %w(institutions)

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
          db_rsp = r.table_create(table, { :primary_key => 'objectID' }).run(conn)
          puts "Succesfully creating table #{table}".green
        rescue
          puts "Error creating table #{table}".red
          puts db_rsp.to_s.red
        end
      end
    end
  end
end

namespace :data do
  desc 'Parse the json data'
  task :parse_data do
    # For each table that we have, we expect a corresponding fixture file
    folder_root = 'fixtures'
    model       = 'institutions'
    path        = File.expand_path "#{folder_root}/#{model}.json", File.dirname(__FILE__)
    json        = JSON.load(File.new(path))
    model_array = json['features']
    r.connect(db: DATABASE) do |conn|
      model_array.each do |m|
        model_object = {
          'objectID'   => m['properties']['id'],
          'name'       => m['properties']['name'],
          'geometry'   => m['geometry'],
          'searchRate' => 0 # How many time this item has been looked
        }

        db_resp = r.table(model).get(model_object['objectID']).run(conn)
        print "Inserting object #{model_object['objectID']}..."
        unless db_resp
          op_resp = r.table(model).insert(model_object).run(conn)
          puts 'created!'.green
        else
          model_object.delete('searchRate')
          op_resp = r.table(model).get(model_object['objectID']).update(model_object).run(conn)
          puts 'updated!'.yellow
        end
      end
    end
  end

  desc 'Sync'
  task :sync, [:table] do |t, args|
    begin
      raise 'ALOGLIA_API_KEY environment variable is missing!' if ENV['ALGOLIA_API_KEY'].nil?
      raise 'No sync table defined as rake task argument!' unless args.has_key? :table
      Algolia.init :application_id => "GGUMSS0TFV", :api_key => ENV['ALGOLIA_API_KEY']

      index = Algolia::Index.new('name')
      r.connect(:db => DATABASE) do |conn|
        r.table(args[:table]).run(conn).each_slice(10) { |slice| index.add_objects(slice) }
      end
    rescue Exception => e
      puts e.message.red
    end
  end
end

