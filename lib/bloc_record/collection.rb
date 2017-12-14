module BlocRecord
    class Collection < Array
        def update_all(updates)
            ids = self.map(&:id)
            self.any? ? self.first.class.update(ids, updates) : false
        end
        
        def take()
            self.any? ? self.first : nil
        end
        
        def where(**kwargs)
            BlocRecord::Utility.convert_keys(kwargs)
            retval = []
            self.each do |record|
                include = true
                kwargs.each do |key, value|
                    if record[key] != value
                        include = false
                        break
                    end
                end
                if include
                    retval.append(record)
                end
            end
        end
    end
end