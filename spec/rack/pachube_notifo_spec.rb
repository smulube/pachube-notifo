require File.dirname(__FILE__) + "/../spec_helper"

describe Pachube::NotifoApp do
  include Rack::Test::Methods

  NOTIFO_OK_MESSAGE = %q{{"status": "success", "response_code": 2201, "response_message": "OK" }}
  NOTIFO_FORBIDDEN_MESSAGE = %q{{"status": "error", "response_code": 1102, "response_message": "Not allowed to send to user"}}
  NOTIFO_NO_SUCH_USER_MESSAGE = %q{{"status": "error", "response_code": 1105, "response_message": "No such user"}}
  NOTIFO_SUBSCRIBE_FORBIDDEN_MESSAGE = %q{{"status": "error", "response_code": 1106, "response_message": "Not allowed to subscribe user"}}

  def app
    Pachube::NotifoApp.new
  end

  before(:each) do
    User.notifo.stub!(:subscribe_user).and_return(NOTIFO_OK_MESSAGE)
    User.notifo.stub!(:send_message).and_return(NOTIFO_OK_MESSAGE)
    User.notifo.stub!(:send_notification).and_return(NOTIFO_OK_MESSAGE)
  end

  it "should respond to /" do
    get "/"
    last_response.should be_ok
  end

  it "should be able to access the notifo object for stubbing" do
    User.notifo.should_not be_nil
  end

  context "looking at registering a new user successfully" do
    it "should redirect the user" do
      post "/users/register", { :username => "ibrahim" }
      last_response.status.should == 302 
    end

    it "should redirect to index page" do
      post "/users/register", { :username => "ibrahim" }
      follow_redirect!
      last_request.url.should == "http://example.org/"
      last_response.should be_ok
    end

    it "should have created a record for our user in the local database" do
      post "/users/register", { :username => "ibrahim" }
      user = User[:username => "ibrahim"]
      user.should_not be_nil
      user.crypted_secret.should_not be_nil

      # counts will be 1 as we've used a notification to send out the secret message
      user.monthly_message_count.should == 1
      user.message_count.should == 1
    end

    it "should send out a registration message to the user" do
      user = mock("User")
      user.should_receive(:send_message).and_return(NOTIFO_OK_MESSAGE)
      User.stub!(:create).and_return(user)
      post "/users/register", { :username => "ibrahim" }
    end
  end

  context "looking at registering an existing user successfully" do
    before(:each) do
      User.create(:username => "ibrahim", :secret => "footle")
    end

    it "should redirect the user" do
      post "/users/register", { :username => "ibrahim" }
      last_response.status.should == 302 
    end

    it "should redirect to index page" do
      post "/users/register", { :username => "ibrahim" }
      follow_redirect!
      last_request.url.should == "http://example.org/"
      last_response.should be_ok
    end

    it "should have created a record for our user in the local database" do
      User.should_not_receive(:create)
      post "/users/register", { :username => "ibrahim" }
    end

    it "should not send out a registration message to the user" do
      user = mock("User")
      user.should_not_receive(:send_message).and_return(NOTIFO_OK_MESSAGE)
      User.stub!(:create).and_return(user)
      post "/users/register", { :username => "ibrahim" }
    end
  end

  context "looking at when user registration forbidden" do
    before(:each) do
      User.notifo.stub!(:subscribe_user).and_return(NOTIFO_SUBSCRIBE_FORBIDDEN_MESSAGE)
      post "/users/register", { :username => "ibrahim" }
    end

    it "should return a 403 status code" do
      last_response.status.should == 403
    end
  end

  context "regenerating device secrets" do
    before(:each) do
      @user = User.create(:username => "ibrahim", :secret => "foo")
      User.notifo.stub!(:send_message).and_return(NOTIFO_OK_MESSAGE)
    end

    it "should redirect if successful." do
      post "/users/secret", { :username => "ibrahim" }
      last_response.status.should == 302 
    end

    it "should redirect to index page" do
      post "/users/secret", { :username => "ibrahim" }
      follow_redirect!
      last_request.url.should == "http://example.org/"
      last_response.should be_ok
    end

    it "should generate a new device secret" do
      User.stub!(:[]).and_return(@user)
      @user.should_receive(:regenerate_secret)
      post "/users/secret", { :username => "ibrahim" }
    end
    
    it "should send out a new device secret to the user" do
      User.stub!(:[]).and_return(@user)
      @user.should_receive(:send_message).and_return(NOTIFO_OK_MESSAGE)
      post "/users/secret", { :username => "ibrahim" }
    end
  end

  context "looking at delivering notifications" do
    before(:all) do
      @trigger_body = <<-EOF
{
  "environment": {
    "description": "Liveish data on the current status of this Barclays Cycle hire station. Data sourced from the TFL's bike hire map, via Adrian Short's Boris Bike API.", 
    "feed": "http:\/\/api.pachube.com\/v2\/feeds\/15377", 
    "id": 15377, 
    "location": {
      "lat": "51.52469624", 
      "lon": "-0.08443928", 
      "name": "Leonard Circus , Shoreditch"
    }, 
    "title": "Boris Bike Station: 32 - Leonard Circus , Shoreditch"
  }, 
  "id": 1118, 
  "threshold_value": "2", 
  "timestamp": "2011-02-03T20:10:37Z", 
  "triggering_datastream": {
    "id": "0", 
    "url": "http:\/\/api.pachube.com\/v2\/feeds\/15377\/datastreams\/0", 
    "value": {
    "max_value": 21.0, 
    "min_value": 1.0, 
    "value": "2"
    }
  }, 
  "type": "lte", 
  "url": "http:\/\/api.pachube.com\/v2\/triggers\/1118"
}
      EOF
    end

    context "when remote request is successful" do
      before(:each) do
        User.notifo.stub!(:send_notification).and_return(::NOTIFO_OK_MESSAGE)
        @user = User.create(:username => "bob", :secret => "secret")
      end

      it "should deliver the message successfully" do
        post "/users/bob/deliver?secret=secret", { :body => @trigger_body }
        last_response.should be_ok
      end

      it "should increment the monthly_message_count value on user" do
        count = @user.monthly_message_count
        post "/users/bob/deliver?secret=secret", { :body => @trigger_body }
        @user.reload
        @user.monthly_message_count.should == (count + 1)
      end

      it "should increment the total message_count attribute on user" do
        count = @user.message_count
        post "/users/bob/deliver?secret=secret", { :body => @trigger_body }
        @user.reload
        @user.message_count.should == (count + 1)
      end
    end

    context "when remote request returns forbidden message" do
      before(:each) do
        User.notifo.stub!(:send_notification).and_return(NOTIFO_FORBIDDEN_MESSAGE)
        @user = User.create(:username => "bob", :secret => "secret")
      end

      it "should not be successful" do
        post "/users/bob/deliver?secret=secret", { :body => @trigger_body }
        last_response.should_not be_ok
        last_response.status.should == 403
        last_response.body.should == "Forbidden from sending to that user by Notifo"
      end
    end
    
    context "when remote request returns no such user message" do
      before(:each) do
        User.notifo.stub!(:send_notification).and_return(::NOTIFO_NO_SUCH_USER_MESSAGE)
        @user = User.create(:username => "bob", :secret => "secret")
      end

      it "should not be successful" do
        post "/users/bob/deliver?secret=secret", { :body => @trigger_body }
        last_response.should_not be_ok
        last_response.status.should == 404
        last_response.body.should == "Unable to locate Notifo user"
      end
    end
  end
end
