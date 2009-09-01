class Basketcase
  # Represents the status of an element
  class ElementStatus
    def initialize(path, status, base_version = nil)
      @path = path
      @status = status
      @base_version = base_version
    end

    attr_reader :path, :status, :base_version

    def to_s
      s = "#{path} (#{status})"
      s += " [#{base_version}]" if base_version
      return s
    end
  end
end