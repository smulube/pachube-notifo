require File.dirname(__FILE__) + "/../spec_helper"

describe Pachube::NotifoApp do
  include Rack::Test::Methods

  def app
    Pachube::NotifoApp.new
  end

  it "should respond to /" do
    get "/"
    last_response.should be_ok
  end

  context "looking at registering users successfully" do
    before(:each) do
      User.stub!(:subscribe).and_return(Pachube::NOTIFO_OK_MESSAGE)
      post "/users/register", { :username => "ibrahim" }
    end

    it "should redirect the user" do
      last_response.status.should == 302 
    end

    it "should redirect to index page" do
      follow_redirect!
      last_request.url.should == "http://example.org/"
      last_response.should be_ok
    end
  end
end
