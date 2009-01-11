namespace :db do
  namespace :branch do
    desc "Append config/database.branch.* to .gitignore if missing"
    task :setup => :environment do
      File.open("#{Rails.root}/.gitignore", "a+") do |f| 
        if f.grep(/config\/database\.branch\.\*/).any?
          puts "ignore line found in .gitignore"
        else
          f.write("\nconfig/database.branch.*\n") unless 
          puts "Appended ignore line to .gitignore"
        end
      end
    end

    desc "Create the branch-specific database file and init db"
    task :create => :environment do
      config = YAML.load_file("#{Rails.root}/config/database.yml")
      config.delete_if { |k,v| v["database"].nil? }
      config.keys.each do |env|
        name = config[env]["database"]
        config[env]["database"] = name =~ /#{env}/ ? name.sub(/#{env}/, "#{env}_#{Sevenwire::DbBranch.branch}") : "#{name}_#{Sevenwire::DbBranch.branch}"
      end
      File.open(Sevenwire::DbBranch.database_file_for_branch, "w") {|f| f.write(YAML.dump(config)) }
      Rake::Task['environment'].invoke
      Rake::Task['db:create:all'].invoke
      Rake::Task['db:schema:load'].invoke
      Rake::Task['db:test:prepare'].invoke
      puts "Unless we ran into any errors, the branch databases (#{config.map {|k,v| v['database']}.to_sentence}) have all been created."
      puts "The schema has been loaded into the #{Rails.env} env db, #{config[Rails.env]['database']} and test db prepared. Use rake db:branch:clone if you wish to load the data"
    end

    desc "Clone database from original database.yml, set RAILS_ENV to switch dbs"
    task :clone => :environment do
      original_config = YAML.load_file("#{Rails.root}/config/database.yml")[Rails.env]
      branch_config = YAML.load_file(Sevenwire::DbBranch.database_file_for_branch)[Rails.env]
      case original_config['adapter']
      when 'mysql'
        if Rails.configuration.database_configuration_file == Sevenwire::DbBranch.database_file_for_branch
          Rake::Task['db:drop'].invoke
          Rake::Task['db:create'].invoke
          cli = "mysqldump #{mysql_params(original_config)} | mysql #{mysql_params(branch_config)}"
          #puts "executing: #{cli}"
          `#{cli}`
          Rake::Task['db:test:prepare'].invoke
          puts "Data loaded from #{original['database']} into #{branch_config['database']} and test db prepared"
        else
          puts "Setup and Create your branch config first!"
        end
      else
        puts "Don't know how to dump and load using #{original_config['adapter']}, how about adding support for it?"
      end
    end

    def mysql_params(config)
      params = "-u #{config['username']}"
      params << " -h #{config['host']}" unless config['host'].blank?
      params << " --password=#{config['password']}" unless config['password'].blank?
      params << " #{config['database']}"
      params
    end
  end
end
