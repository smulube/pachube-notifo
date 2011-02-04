require "rubygems"
require "bundler/setup"

require "sinatra/base"
require "haml"
require "sinatra/sequel"
require "sequel"
require "rack-flash"
require "yaml"
require "notifo"
require "json"
require "lib/exceptions"

module Pachube

  NOTIFO_OK = 2201
  NOTIFO_ACCEPTED = 2202
  NOTIFO_FORBIDDEN = 1102
  NOTIFO_NO_SUCH_USER = 1105
  NOTIFO_SUBSCRIBE_FORBIDDEN = 1106

  NOTIFO_OK_MESSAGE = { "status" => "success", "response_code" => 2201, "response_message" => "OK" }

  class NotifoApp < Sinatra::Base
    register Sinatra::SequelExtension
  
    helpers Sinatra::SequelHelper
  
    use Rack::Lint
    use Rack::Flash, :sweep => true
  
    # Create environment specific database
    set :database, "sqlite://data/pachube-notifo-#{environment}.db"
  
    # Migration - I think the name of the migration is what controls whether or
    # not it's been run previously or not, so don't change this or bad things
    # might happen.
    migration "Create the users table" do
      database.create_table :users do
        primary_key :id
        column :username, :string
        column :crypted_secret, :string
        column :message_count, :integer, :default => 0, :null => false
        column :created_at, :timestamp
        column :updated_at, :timestamp
      
        index :username, :unique => true
      end
    end
  
    migration "Add counter table" do
      database.create_table :statistics do
        primary_key :id
        column :monthly_count, :integer, :default => 0, :null => false
        column :total_count, :integer, :default => 0, :null => false
      end
    end
  
    configure do
      # load config file
      config_file = YAML.load_file(File.join(File.dirname(__FILE__), "config/settings.yml"))

      # config options that should be set for all environments
      set :sessions, true
      set :logging, true
      set :haml, :format => :html5
      set :public, File.dirname(__FILE__) + "/public"
    
      # Load the automatic timestamps Sequel plugin (for auto setting updated_at,
      # created_at)
      Sequel::Model.plugin :timestamps
  
      # Create our Notifio client object and stuff into a settings variable
      set :notifo => Notifo.new(config_file["notifo"]["username"], config_file["notifo"]["secret"])

      # Set our monthly_usage_limit
      set :monthly_usage_limit => config_file["notifo"]["monthly_usage_limit"]
  
      # Setting to control whether or not to actual try and deliver outgoing
      # messages/notifications
      set :enable => config_file["notifo"]["enable"]
  
      # require our model classes here, which runs after the database object has
      # been initialized
      require "models/user"
  
      # # Pass our Notifo object into the model base
      # User.notifo = settings.notifo
    end
  
    helpers do
      # def set_status(notifo_response)
      #   puts "Raising error for #{notifo_response.inspect}"
      #   case notifo_response["response_code"]
      #   when NOTIFO_NO_SUCH_USER, NOTIFO_FORBIDDEN, NOTIFO_SUBSCRIBE_FORBIDDEN
      #     status 404
      #     #raise Sinatra::NotFound, notifo_response["response_message"]
      #   else
      #     status 500
      #     #raise Sinatra::ServerError, notifo_response["response_message"]/
      #   end
      # end
      def find_user
        @user = User.authenticate(params[:username], params[:secret])
        raise Sinatra::NotFound if @user.nil?
      end
  
      def check_total_monthly_usage
        # create our counter row if it doesn't yet exist
        if database[:statistics][:id => 1].nil?
          database[:statistics].insert(:monthly_count => 0, :total_count => 0)
        end
  
        # prevent delivery if we have reached our monthly quota
        raise ServiceUnavailable if database[:statistics][:id => 1][:monthly_count] > settings.monthly_usage_limit
      end
    end
  
    before '/users/:username/deliver' do
      find_user
      check_total_monthly_usage
    end
  
    get "/" do
      haml :index
    end
  
    post "/users/register" do
      @user = User.register(params[:username])
      flash[:notice] = "User registered successfully. You should have received a message containing your secret. You'll need this to start sending notifications"
      redirect "/"
    end
  
    post "/users/:username/deliver" do
      trigger_content = JSON.parse(params[:body])
      response = @user.send_notification("'#{trigger_content["type"]}' event triggerd by feed #{trigger_content["environment"]["id"]}, datastream #{trigger_content["triggering_datastream"]["id"]} with a value of #{trigger_content["triggering_datastream"]["value"]} at #{trigger_content["timestamp"]}", "Pachube Trigger Notification", "http://www.pachube.com/feeds/#{trigger_content["environment"]["id"]}")
      case response["response_code"]
      when Pachube::NOTIFO_OK
        halt 200
      when Pachube::NOTIFO_FORBIDDEN, Pachube::NOTIFO_NO_SUCH_USER
        raise NotFound
      else
        raise Sinatra::ServerError
      end
    end
  
    # ------------------------------------------------------------------------------- 
    # Start of admin type actions that should be protected
    # ------------------------------------------------------------------------------- 
    
    get "/users/:username" do
      @user = User[:username => params[:username]]
      haml :"users/show"
    end
  
    get "/users" do
      @users = User.all
      haml :"users/index"
    end
  
  end
end
