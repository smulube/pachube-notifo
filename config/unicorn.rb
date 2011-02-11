APP_PATH = "/home/sam/workspace/sinatra/pachube_notifo/"

worker_processes 2
working_directory APP_PATH

preload_app true

timeout 30

listen "#{APP_PATH}tmp/sockets/unicorn.sock", :backlog => 64
listen 8080, :tcp_nopush => true

pid = "#{APP_PATH}pids/unicorn.pid"

stderr_path = "#{APP_PATH}log/unicorn.stderr.log"
stdout_path = "#{APP_PATH}log/unicorn.stdout.log"

# before_fork do |server, worker|
#   defined?(DB) && DB.disconnect
# end
# 
# after_fork do |server, worker|
#   DB = Sequel.connect("sqlite://data/pachube-notifo-development.db")
# end
