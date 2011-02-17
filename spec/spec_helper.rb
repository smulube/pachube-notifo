# Set up some env variables and constants we want to use
ENV["RACK_ENV"] = "test"
ENV["AUTH_USERNAME"] = "admin"
ENV["AUTH_PASSWORD"] = "passwd"

NOTIFO_OK_MESSAGE = %q{{"status": "success", "response_code": 2201, "response_message": "OK" }}
NOTIFO_FORBIDDEN_MESSAGE = %q{{"status": "error", "response_code": 1102, "response_message": "Not allowed to send to user"}}
NOTIFO_NO_SUCH_USER_MESSAGE = %q{{"status": "error", "response_code": 1105, "response_message": "No such user"}}
NOTIFO_SUBSCRIBE_FORBIDDEN_MESSAGE = %q{{"status": "error", "response_code": 1106, "response_message": "Not allowed to subscribe user"}}

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'pachube_notifo'))

require 'rspec'
require 'rack/test'

RSpec.configure do |c|
  c.around(:each) do |example|
    Pachube::NotifoApp.database.transaction do
      example.run
      raise Sequel::Error::Rollback
    end
  end
end
