
class Basketcase
  module Utils
    def mkpath(path)
      path = path.to_str
      path = path.tr('\\', '/')
      path = path.sub(%r{^\./},'')
      path = path.sub(%r{^([A-Za-z]):\/}, '/cygdrive/\1/')
      Pathname.new(path)
    end
  end
  
end