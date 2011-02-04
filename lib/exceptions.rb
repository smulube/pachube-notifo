class ServiceUnavailable < StandardError
  def code
    503
  end
end

class NotRegistered < StandardError
  def code
    403
  end
end
