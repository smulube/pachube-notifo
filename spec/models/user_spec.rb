require File.dirname(__FILE__) + "/../spec_helper"

describe User do

  it "should see the User class" do
    User.should_not be_nil
  end

  it "should be able to create a user" do
    user = User.new(:username => "bob", :secret => "passwd")
    user.save
    user.reload
    user.username.should == "bob"
    user.crypted_secret.should_not be_nil
  end
end
