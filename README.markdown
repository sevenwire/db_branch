DB\_BRANCH
==========

Rails plugin to play nice with git branching and databases. Loads a
branch-specific database YAML file allowing you to migrate in branches without
affecting the database of other branches.

More information:

* [http://sevenwire.com/blog/2008/12/03/introducing-db-branch.html](http://sevenwire.com/blog/2008/12/03/introducing-db-branch.html)
* [http://cryingwhilecoding.com/2009/1/11/easily-manage-db-changes-between-branches-in-git](http://cryingwhilecoding.com/2009/1/11/easily-manage-db-changes-between-branches-in-git)


Usage
-----

First, you should have your db backed up. Just saying.

By default, it will run setup, config, and create_clone tasks so you'll end up
with a running copy of your existing db for your branch.

    rake db:branch

Update the db again? The `clone` task will drop and recreate the db and reload it
from the original.

    rake db:branch:clone

Just want a clean db without the data? `create_empty` will create the config and
just load the db from the schema.

    rake db:branch:create_empty

No longer need the branched db? `purge` will remove the branched databases and
config.

    rake db:branch:purge


Branch database config files are named `database.branch.[branch_name].yml`. The
database names for the branch are renamed as
`[application]_[environment]_[branch]` or `[databasename]_[branch]` if the
originals where not named using a `[application]_[environment]` convention.

You can alter which branch name is used for the creation or purging of databases
and config by setting the `DB\_BRANCH` variable.

    rake db:branch DB_BRANCH=refactor

You can alter which database is used for the cloning or schema loading by
setting the `RAILS\_ENV` variable.

    rake db:branch:clone RAILS_ENV=development


Explicitly configuring which environments to branch
---------------------------------------------------
I have a project that has a lot of tunneled connections defined in it's
config/database.yml. I do not want the plugin to attempt to create branched
versions of all these dbs, so I added support for explicitly stating which
environments should have the db branched by adding a branch: true or false to
the database.yml where appropriate. So, if you just want production and
development dbs to be branched, you can set branch: true to those stanzas of the
config and the rest will be included in the new config unmanipulated. 

Once 'branch' has been defined in any stanza, any stanza lacking it or having it
set to something that does not evaluate to true will be treated as a remote db,
effectively omitting it from the create/drop tasks.



But can it go to Eleven?
------------------------
The only thing I can imagine making this any better is possibly finding a way of
using gits hooks to automatically run rake db:branch when creating a new branch
and rake db:branch:purge when deleting a branch. That'd be pretty hot.


Authors
-------

* Nate Sutton (nate@sevenwire.com)
* Brandon Arbini (brandon@sevenwire.com)
* Mike Vincent (mike@cryingwhilecoding.com)
* Bjørn Arild Mæland (bjorn.maeland@gmail.com)
* Chris Griego (cgriego@gmail.com)
