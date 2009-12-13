require "fileutils"

module Sevenwire
  class DbBranch
    def self.load_database
      if branch? && database_file_for_branch?
        Rails.configuration.database_configuration_file = database_file_for_branch
        ActiveRecord::Base.configurations = Rails.configuration.database_configuration
        ActiveRecord::Base.establish_connection
      end
    end

    def self.database_file_for_branch
      "#{Rails.root}/config/database.branch.#{branch(:fs)}.yml"
    end

    def self.database_file_for_branch?
      File.exists?(database_file_for_branch)
    end

    def self.branch?
      !branch.blank?
    end

    def self.branch(sanitize_for=nil)
      return false unless git? && git_repository?
      
      branch = ENV['DB_BRANCH'] || `git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \\(.*\\)/\\1/'`.chomp
      
      case sanitize_for
      when :db then branch.gsub!('/', '_')
      when :fs then branch.gsub!('/', '.')
      end
      
      branch
    end

    def self.git?
      !`which git`.blank?
    end

    def self.git_repository?
      File.exists?("#{Rails.root}/.git")
    end
  end
end

Sevenwire::DbBranch.load_database
