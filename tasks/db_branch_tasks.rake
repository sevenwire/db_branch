namespace :db do
  def explicit_branches?
    @all_db_configs ||= YAML.load_file("#{Rails.root}/config/database.yml")
    @all_db_configs.any? {|env,config| config.keys.include?('branch') }
  end

  # Override local_database? method to only yield 
  # if configured to branch, useful if you have tunneled connections or something
  # you want to prevent branching of
  def local_database?(config, &block)
    if %w( 127.0.0.1 localhost ).include?(config['host']) || config['host'].blank?
      if !explicit_branches? || config['branch']
        yield
      else
        puts "Not configured to branch #{config['database']}, skipping."
      end
    else
      puts "This task only modifies local databases. #{config['database']} is on a remote host."
    end
  end

  task :branch => "branch:create_clone"

  # Chain onto the default load_config task
  task :load_config => [:environment,:rails_env] do
    Sevenwire::DbBranch.load_database
  end

  namespace :branch do
    desc "Append config/database.branch.* to .gitignore if missing"
    task :setup => :environment do
      File.open("#{Rails.root}/.gitignore", "r+") do |f|
        if f.grep(/config\/database\.branch\.\*/).any? # advances seek to end of file
          puts "Found ignore line in .gitignore"
        else
          f.puts "config/database.branch.*"
          puts "Appended ignore line to .gitignore"
        end
      end
    end

    desc "Creates a new database config for branch"
    task :config => [:environment,:setup] do
      if !Sevenwire::DbBranch.database_file_for_branch?
        config = YAML.load_file("#{Rails.root}/config/database.yml")
        config.delete_if { |k,v| v["database"].nil? }
        config.keys.each do |env|
          next unless config[env]['branch'] if explicit_branches?
          name = config[env]["database"]
          config[env]["database"] = name =~ /#{env}/ ? name.sub(/#{env}/, "#{env}_#{Sevenwire::DbBranch.branch(:db)}") : "#{name}_#{Sevenwire::DbBranch.branch(:db)}"
        end
        File.open(Sevenwire::DbBranch.database_file_for_branch, "w") do |f| 
          f.puts "# Branched database configuration for #{Sevenwire::DbBranch.branch} branch of development" 
          f.puts "# rake db:branch:purge will drop the branched databases and remove this config file"
          f.puts(YAML.dump(config)) 
        end
        puts "Wrote new config for branched db: #{Sevenwire::DbBranch.database_file_for_branch}"
      else
        puts "#{Sevenwire::DbBranch.database_file_for_branch} already exists"
      end
      # ensure we're using the new branch config
      Sevenwire::DbBranch.load_database
    end

    desc "Create empty database by loading the schema and preparing the test db"
    task :create_empty => [:environment,:setup, :config] do
      Rake::Task['environment'].invoke
      if Rails.configuration.database_configuration_file == Sevenwire::DbBranch.database_file_for_branch
        Rake::Task['db:create:all'].invoke
        Rake::Task['db:schema:load'].invoke
        Rake::Task['db:test:prepare'].invoke
        puts "Unless we ran into any errors, the branch databases have all been created."
        puts "The schema has been loaded into the #{Rails.env} env branch db, and test db prepared."
      else
        puts "Aborted! Not using branch config! Run rake:db:branch:config to create it."
      end
    end

    desc "Create cloned database by loading branch from a dump of current db and preparing test db"
    task :create_clone => [:environment,:setup, :config] do
      Rake::Task['db:create:all'].invoke
      Rake::Task['db:branch:clone'].invoke
      puts "\nPreparing the test db, if there are any pending migrations you'll need to run rake db:test:prepare after migrating."
      Rake::Task['db:test:prepare'].invoke
    end

    desc "Clone database from original database.yml, set RAILS_ENV to switch dbs"
    task :clone => :environment do
      if Rails.configuration.database_configuration_file == Sevenwire::DbBranch.database_file_for_branch
        original_config = YAML.load_file("#{Rails.root}/config/database.yml")[Rails.env]
        branch_config = YAML.load_file(Sevenwire::DbBranch.database_file_for_branch)[Rails.env]
        case original_config['adapter']
        when 'mysql'
          Rake::Task['db:drop'].invoke
          Rake::Task['db:create'].invoke
          cli = "mysqldump #{mysql_params(original_config)} | mysql #{mysql_params(branch_config)}"
          `#{cli}`
          puts "Data loaded from #{original_config['database']} into #{branch_config['database']}"
        when 'sqlite3'
          if File.exists?(original_config['database'])
            FileUtils.copy_file(original_config['database'], branch_config['database'])
            puts "Data loaded from #{original_config['database']} into #{branch_config['database']}"
          end
        when 'postgresql'
          copy_postgres_database(original_config, branch_config['database'])
          puts "Data loaded from #{original_config['database']} into #{branch_config['database']}"
        else
          puts "Don't know how to dump and load using #{original_config['adapter']}, how about adding support for it?"
        end
      else
        puts "Aborted! Not using branched database config! Run rake:db:branch:config to create it."
      end
    end

    desc "Drops the branch databases and removes the branch config file"
    task :purge => :environment do
      if Rails.configuration.database_configuration_file == Sevenwire::DbBranch.database_file_for_branch
        Sevenwire::DbBranch.load_database
        #Rake::Task['db:drop:all'].invoke
        ActiveRecord::Base.configurations.each_value do |config|
          # Skip entries that don't have a database key
          next unless config['database']
          # Only connect to local databases
          begin
            puts "Attempting to drop #{config['database']}"
            local_database?(config) { drop_database(config) }
          rescue
            puts "caught and ignored exception: #{$!}"
          end
        end
        File.unlink Sevenwire::DbBranch.database_file_for_branch
        puts "Dropped branch databases and removed branch config file"
      else
        puts "Aborted! You are not using a branched db?"
      end
    end

    def mysql_params(config)
      params = "-u #{config['username']}"
      params << " -h #{config['host']}" unless config['host'].blank?
      params << " --password=#{config['password']}" unless config['password'].blank?
      params << " #{config['database']}"
      params
    end
    
    def copy_postgres_database(config, branch_database)
      # TODO: use .pgpass file to authenticate?
      #
      # TODO: another approach to creating a pg copy might be to 
      #       dropdb target_db; createdb -T target_db
      #
      auth_data = "-U #{config['username']}"
      auth_data << " -h #{config['host']}" if config['host']
      auth_data << " -p #{config['port']}" if config['port']
      
      dump_flags = "-F c -b"
      
      cmd = "export PGPASSWORD=#{config['password']};"
      cmd << "pg_dump #{auth_data} #{dump_flags} #{config['database']} | pg_restore #{auth_data} -d #{branch_database}"
      cmd << "; unset PGPASSWORD"
      `#{cmd}`
    end
  end
end
