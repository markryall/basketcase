unless [].respond_to?(:each_slice)
  puts "PATCHING"
  class Array
    def each_slice count
      items = []
      self.each do |item|
        items << item
        if items.length == count
          yield items 
          items = []
        end
      end
      yield items if items.length > 0
    end
  end
end