DB\_BRANCH
==========

Rails plugin to play nice with git branching and databases. Loads a branch-specific database YAML file allowing you to migrate in branches without affecting the database of other branches.

More information:  
http://sevenwire.com/blog/2008/12/03/introducing-db-branch.html

Usage
-----

First, you'll want to run setup which currently adds `config/database.branch.*` to `.gitignore`.

    rake db:branch:setup

Next, from a branch, you'll create your new branch-specific database.

    rake db:branch:create

This will create a new YAML file in config called `database.branch.[branch_name].yml`, change the database names to `[application or db name if unable to infer env]_[environment]_[branch]`, create all databases, load the schema, and prepare the test database.

Optionally, clone an existing db

    rake db:branch:clone

This will drop and recreate the current db, then load it from a mysqldump of the db from the original config file. Load different dbs by changing the RAILS_ENV variable.

    rake db:branch:clone RAILS_ENV=development


Authors
-------

Nate Sutton (nate@sevenwire.com)  
Brandon Arbini (brandon@sevenwire.com)
Mike Vincent (mike@cryingwhilecoding.com)
