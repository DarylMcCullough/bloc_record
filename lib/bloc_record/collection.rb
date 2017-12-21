module BlocRecord
    class Collection < Array
        def update_all(updates)
            ids = self.map(&:id)
            self.any? ? self.first.class.update(ids, updates) : false
        end
        
        def take(n=1)
            if not(n.is_a? Integer) || n < 1
                raise ArgumentError.new("take: argument must be a positive integer")
            end
            return self.sample(n)
        end
        
        def destroy_all(*args)
            if self.count == 0
                return
            end
            
            if args.count == 0
                self.each do |entry|
                    entry.destroy()
                end
                return
            end
            if args.count > 1
                expression = args.shift
                id_expression = self.get_id_expression()
                expression = "(#{expression}) AND (#{id_expression})"
                params = args
                self.first.class.destroy_all(expression, *params)
                return
            else
                case args.first
                when String
                    expression = args.first
                    id_expression = self.get_id_expression()
                    expression = "(#{expression}) AND (#{id_expression})"
                    self.first.class.destroy_all(expression)
                    return
                when Hash
                    hash = args.first
                    self.each do |entry|
                        hash["id"] = entry.send("id")
                    end
                    self.first.class.destroy_all(hash)
                    return
                end
            end
            raise ArgumentError.new("destroy_all: arguments must be strings or hashes")
        end
        
        def where(**kwargs)
            BlocRecord::Utility.convert_keys(kwargs)
            retval = []
            self.each do |record|
                include = true
                kwargs.each do |key, value|
                    if record.send(key) != value
                        include = false
                        break
                    end
                end
                if include
                    retval.append(record)
                end
            end
        end
        
        def destroy_all()
            self.each do |record|
                record.destroy()
            end
        end
        
        def not(**kwargs)
            BlocRecord::Utility.convert_keys(kwargs)
            retval = []
            self.each do |record|
                include = true
                kwargs.each do |key, value|
                    if record.send(key) == value
                        include = false
                        break
                    end
                end
                if include
                    retval.append(record)
                end
            end
        end
        
        private
        def get_id_expression()
            ids = self.map { |entry| entry.send("id") }
            expression = 'id IN (#{ids.join(",")})'
            return expression
        end
    end
end