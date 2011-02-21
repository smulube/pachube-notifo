require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")

describe User do
  before(:all) do
    @json = JSON.parse(IO.read("spec/trigger.json"))
    @debug_json = JSON.parse(IO.read("spec/debug_trigger.json"))
  end

  before(:each) do
    User.notifo.stub!(:send_notification).and_return(NOTIFO_OK_MESSAGE)
  end

  it "should see the User class" do
    User.should_not be_nil
  end

  it "should be able to create a user" do
    user = User.new(:username => "bob", :secret => "passwd")
    user.save
    user.reload
    user.username.should == "bob"
  end

  it "should crypt the secret if present" do
    user = User.new(:username => "bob", :secret => "passwd")
    user.save
    user.reload
    user.crypted_secret.should_not be_nil
  end

  it "should have a method that returns a nicely formatted operator string" do
    User.operator("lte", "4.5").should == "<= 4.5"
    User.operator("lt", "13").should == "< 13"
    User.operator("gt", "18.9").should == "> 18.9"
    User.operator("gte", "4").should == ">= 4"
    User.operator("eq", "4").should == "== 4"
    User.operator("change", nil).should == "is a change"

    lambda {
      User.operator("foo", "12.3")
    }.should raise_error
  end

  it "should have a higher level method for creating an outgoing notification message" do
    user = User.create(:username => "bob", :secret => "passwd")
    user.send_trigger_notification(@json, "www.pachube.com").should == JSON.parse(NOTIFO_OK_MESSAGE)
  end

  it "should send our composed message to notifo" do
    user = User.create(:username => "bob", :secret => "passwd")
    user.should_receive(:send_notification).with("Event: 4.7 > 3. Feed - 'space weather', datastream 2, value: {\"max_value\"=>23.2, \"min_value\"=>0.1, \"value\"=>\"4.7\"} at 2011-01-28T15:53:38Z", "Pachube Trigger Notification", "http://www.pachube.com/feeds/256")
    user.send_trigger_notification(@json, "www.pachube.com")
  end

  it "should send a different composed message if the current notification is a debug test" do
    user = User.create(:username => "bob", :secret => "passwd")
    user.should_receive(:send_notification).with("[DEBUG] Event: 4.7 > 3. Feed - 'space weather', datastream 2, value: {\"max_value\"=>23.2, \"min_value\"=>0.1, \"value\"=>\"4.7\"} at 2011-01-28T15:53:38Z", "Pachube Trigger Notification", "http://www.pachube.com/feeds/256")
    user.send_trigger_notification(@debug_json, "www.pachube.com")
  end
end
