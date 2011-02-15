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
require "sinatra/logger"

module Pachube

  NOTIFO_OK = 2201
  NOTIFO_ACCEPTED = 2202
  NOTIFO_FORBIDDEN = 1102
  NOTIFO_NO_SUCH_USER = 1105
  NOTIFO_SUBSCRIBE_FORBIDDEN = 1106

  class NotifoApp < Sinatra::Base
    register Sinatra::SequelExtension
  
    helpers Sinatra::SequelHelper
  
    use Rack::Lint
    use Rack::Flash, :sweep => true
  
    # Create environment specific database
    set :database, "sqlite://data/pachube-notifo-#{environment}.db"
  
    set :root, File.expand_path(File.dirname(__FILE__))

    register Sinatra::Logger
    helpers Sinatra::Logger::Helpers

    # Migration - I think the name of the migration is what controls whether or
    # not it's been run previously or not, so don't change this or bad things
    # might happen.
    #
    # TODO: Figure out how to put this stuff in a separate file
    migration "Create the users table" do
      database.create_table :users do
        primary_key :id
        column :username, :string
        column :crypted_secret, :string
        column :message_count, :integer, :default => 0, :null => false
        column :monthly_message_count, :integer, :default => 0, :null => false
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

      # Load the pagination extension
      Sequel.extension :pagination
  
      # Create our Notifio client object and stuff into a settings variable
      set :notifo => Notifo.new(config_file["notifo"]["username"], config_file["notifo"]["secret"])

      # Set our monthly_usage_limit
      set :monthly_usage_limit => config_file["monthly_usage_limit"]

      # Set our user_monthly_usage_limit
      set :user_monthly_usage_limit => config_file["user_monthly_usage_limit"]
  
      # require our model classes here, which runs after the database object has
      # been initialized
      require "models/user"
  
      # # Pass our Notifo object into the model base
      User.notifo = settings.notifo

      # Set our basic auth username and password
      set :auth_username, config_file["auth_username"]
      set :auth_password, config_file["auth_password"]
    end

    configure :development, :test do
      set :logger_level, :debug
    end
  
    helpers do

      def authenticate_user_by_secret
        logger.debug("Attempting to authenticate user: #{params[:username]}")
        @user = User.authenticate_by_secret(params[:username], params[:secret])
        raise Sinatra::NotFound if @user.nil?
      end

      def find_user
        @user = User[:username => params[:username]]
      end
  
      def check_total_monthly_usage
        logger.debug("Checking total monthly usage")
        # create our counter row if it doesn't yet exist
        if database[:statistics][:id => 1].nil?
          database[:statistics].insert(:monthly_count => 0, :total_count => 0)
        end
  
        # prevent delivery if we have reached our monthly quota
        raise ServiceUnavailable if database[:statistics][:id => 1][:monthly_count] >= settings.monthly_usage_limit
      end

      def check_user_monthly_usage
        logger.debug("Checking users monthly usage")
        raise(Forbidden, "Monthly usage over quota") if @user.monthly_message_count >= settings.user_monthly_usage_limit
      end

      def protected!
        unless authorized?
          response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
          throw(:halt, [401, "Not authorized\n"])
        end
      end

      def authorized?
        @auth ||=  Rack::Auth::Basic::Request.new(request.env)
        @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [settings.auth_username, settings.auth_password]
      end
    end
    
    # ------------------------------------------------------------------------------- 
    # Error handlers
    # ------------------------------------------------------------------------------- 
    
    error Forbidden do
      status 403
      "Access forbidden: #{request.env["sinatra.error"].message}"
    end

    error ServiceUnavailable do
      "Service unavailable: #{request.env["sinatra.error"].message}"
    end

    # ------------------------------------------------------------------------------- 
    # Before filters
    # ------------------------------------------------------------------------------- 
  
    before '/users/:username/deliver' do
      authenticate_user_by_secret
      check_total_monthly_usage
      check_user_monthly_usage
    end

    before '/users/secret' do
      find_user
    end

    # ------------------------------------------------------------------------------- 
    # Start of our actions
    # ------------------------------------------------------------------------------- 
    
    get "/" do
      haml :index
    end

    post "/users/register" do
      @user = User.register(params[:username])
      flash[:notice] = "User registered successfully. You should have received a message containing your secret. You'll need this to start sending notifications"
      redirect "/"
    end

    post "/users/secret" do
      @user.regenerate_secret
      flash[:notice] = "Device secret generated and sent out successfully."
      redirect "/"
    end

    post "/users/:username/deliver" do
      trigger_content = JSON.parse(params[:body])
      response = @user.send_notification("'#{trigger_content["type"]}' event; feed #{trigger_content["environment"]["id"]}, datastream #{trigger_content["triggering_datastream"]["id"]}, value: #{trigger_content["triggering_datastream"]["value"].inspect} at #{trigger_content["timestamp"]}", "Pachube Trigger Notification", "http://www.pachube.com/feeds/#{trigger_content["environment"]["id"]}")
      case response["response_code"]
      when Pachube::NOTIFO_OK
        halt 200
      when Pachube::NOTIFO_FORBIDDEN
        error 403, "Forbidden from sending to that user by Notifo"
      when Pachube::NOTIFO_NO_SUCH_USER
        error 404, "Unable to locate Notifo user"
      else
        error 500, "Service unavailable"
      end
    end

    # ------------------------------------------------------------------------------- 
    # Start of admin type actions that should be protected
    # ------------------------------------------------------------------------------- 
    
    get "/admin" do
      protected!
      "hello, #{auth.credentials.inspect}"
      #haml :"admin/index"
    end

    get "/admin/users/:username" do
      protected!
      @user = User[:username => params[:username]]
      raise Sinatra::NotFound if @user.nil?
      #haml :"users/show"
      "This is: #{@user.inspect}"
    end
  
    get "/admin/users" do
      protected!
      @order = (params[:order] || :username).to_sym
      @users = User.order(@order).all
      haml :"admin/users"
    end

    get "/admin/statistics" do
      protected!

      statistics = database[:statistics][:id => 1]
      user_count = User.count

      content_type "text/plain", :charset => "utf-8"
      "Statistics\n# Total messages,Monthly messages,Total users\n#{statistics[:total_count]},#{statistics[:monthly_count]},#{user_count}"
    end
  end
end
