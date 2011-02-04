require "active_support/secure_random"
require "bcrypt"

class User < Sequel::Model
  include BCrypt

  class << self
    attr_accessor :notifo
  end

  attr_accessor :secret

  def self.register(username)
    subscribe_response = subscribe(username)
    case subscribe_response["response_code"]
    when Pachube::NOTIFO_OK, Pachube::NOTIFO_ACCEPTED
      user = User[:username => username]
      if user.nil?
        # create record and send generated secret to user
        secret = create_secret
        user = User.create(:username => username, :secret => secret) 
        user.send_message("Your secret for accessing the Pachube Notifo service is: #{secret}")
      end
      return user
    else
      raise ServiceUnavailable, "Error accessing notifo: #{subscribe_response["message"]}"
    end
  end

  def self.authenticate(username, secret)
    user = User[:username => username]
    user = user && user.authenticated?(secret) ? user : nil
    return user
  end

  # Create a short random string to be used as a user secret. It is short, but
  # is hashed before being stored in the DB.
  def self.create_secret
    ActiveSupport::SecureRandom.hex(3)
  end

  def before_save
    encrypt_secret
    super
  end

  # Send a notification message to this user. Will only work if the user is
  # subscribed to the service.
  def send_notification(message, title =  nil, url = nil, label = nil)
    response = JSON.parse(User.notifo.send_notification(self.username, message, title, uri, label))
    if response["response_code"] == Pachube::NOTIFO_OK
      # increment global counters
      db[:statistics].filter(:id => 1).update(:monthly_count => :monthly_count + 1, :total_count => :total_count + 1)
      # increment count on user record
      db[:users].filter(:username => params[:username]).update(:message_count => :message_count + 1)
    end
    response
  end

  # Send a message to this user.
  def send_message(message)
    JSON.parse(User.notifo.send_message(self.username, message))
  end

  private

  # Return true if the passed in secret authenticates against our stored secret
  def authenticated?(cleartext_secret)
    Password.new(crypted_secret) == cleartext_secret
  end

  # Attempt to subscribe the user to our Notifo service
  def self.subscribe(username)
    return JSON.parse(User.notifo.subscribe_user(username))
  end

  # Encrypt the users secret if present
  def encrypt_secret
    return if @secret.to_s.empty?
    self.crypted_secret = Password.create(@secret)
  end
end
