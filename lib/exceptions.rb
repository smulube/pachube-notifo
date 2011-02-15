class ServiceUnavailable < StandardError
  def code
    503
  end
end

class Forbidden < StandardError
  def code
    403
  end
end
