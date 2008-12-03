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
        config[env]["database"].sub!(/#{env}/, "#{env}_#{Sevenwire::DbBranch.branch}")
      end
      File.open(Sevenwire::DbBranch.database_file_for_branch, "w") {|f| f.write(YAML.dump(config)) }
    end
  end
end
