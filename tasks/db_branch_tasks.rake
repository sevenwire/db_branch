namespace :db do
  namespace :branch do
    desc "Currently just appends config/database.branch.* to .gitignore"
    task :setup => :environment do
      File.open("#{Rails.root}/.gitignore", "a") {|f| f.write("\nconfig/database.branch.*\n") }
    end

    desc "Create the branch-specific database file"
    task :create => :environment do
      config = YAML.load_file("#{Rails.root}/config/database.yml")
      config.keys.each do |env|
        unless config[env]["database"]
          config.delete(env) 
          next
        end
        config[env]["database"].sub!(/#{env}/, "#{env}_#{Sevenwire::DbBranch.branch}")
      end
      File.open(Sevenwire::DbBranch.database_file_for_branch, "w") {|f| f.write(YAML.dump(config)) }
      Rake::Task['environment'].invoke
      Rake::Task['db:create:all'].invoke
      Rake::Task['db:schema:load'].invoke
      Rake::Task['db:test:prepare'].invoke
    end
  end
end
