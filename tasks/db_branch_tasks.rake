namespace :db do
  namespace :branch do
    desc "Append config/database.branch.* to .gitignore, unless it is already"
    task :setup => :environment do
      File.open("#{Rails.root}/.gitignore", "a+") do |f| 
        f.write("\nconfig/database.branch.*\n") unless f.grep(/config\/database\.branch\.\*/).any?
      end
    end

    desc "Create the branch-specific database file"
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
    end
  end
end
