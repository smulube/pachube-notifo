require "rubygems"
require "bundler/setup"

require "sinatra/base"
require "haml"
require "sinatra/sequel"
require "sequel"
require "rack-flash"

class PachubeNotifo < Sinatra::Base
  register Sinatra::SequelExtension
  helpers Sinatra::SequelHelper
  use Rack::Flash, :sweep => true

  set :sessions, true
  set :logging, true
  set :haml, :format => :html5

  #set :run, true

  # Create environment specific database
  set :database, "sqlite://data/pachube-notifo-#{environment}.db"

  # Migration - runs once
  migration "Create the users table" do
    database.create_table :users do
      primary_key :id
      column :username, :string
    
      index :username, :unique => true
    end
  end

  configure do
    # require our model classes here, which runs after the database object has
    # been initialized
    require "models/user"
  end

  get "/" do
    haml :index
  end

  get "/users/new" do
    haml :"users/new"
  end

  post "/register" do
    @user = User.new(:username => params[:username])
    if @user.save
      # ok
      flash[:notice] = "User #{params[:username]} registered successfully"
      redirect "/users"
    else
      # error of some sort
    end
  end

  get "/users/:username" do
    @user = User[:username => params[:username]]
    haml :"users/show"
  end

  get "/users" do
    @users = User.all
    haml :"users/index"
  end
end
