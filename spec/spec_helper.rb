ENV["RACK_ENV"] = "test"

require File.expand_path(File.join(File.dirname(__FILE__), '..', 'pachube_notifo'))

require 'rack/test'

RSpec.configure do |c|
  c.around(:each) do |example|
    Pachube::NotifoApp.database.transaction do
      example.run
      raise Sequel::Error::Rollback
    end
  end
end
