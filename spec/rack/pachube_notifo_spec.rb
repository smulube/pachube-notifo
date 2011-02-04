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
end
