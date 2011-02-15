require "bundler/capistrano"

# Set some globals
default_run_options[:pty] = true

set :application, "pachube_notifo"
set :repository, "git@mulube.unfuddle.com:mulube/pachube_notifo.git"
set :scm, "git"
set :branch, "develop"
set :deploy_via, :export
set :deploy_to, "/u/apps/pachube_notifo"

role :app, "notifo.pachube.com"                          # This may be the same as your `Web` server

# Deployment
set :user, "deploy"

# No sudo
set :use_sudo, false

# If you are using Passenger mod_rails uncomment this:
# if you're still using the script/reapear helper you will need
# these http://github.com/rails/irs_process_scripts

# namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
#   end
# end
