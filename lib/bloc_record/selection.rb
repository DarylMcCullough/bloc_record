require 'sqlite3'
 
module Selection
    def find_one(id)
        if not(id.is_a? Integer) || id < 0
            raise ArgumentError.new("An id must be a nonnegative integer")
        end
        row = connection.get_first_row <<-SQL
            SELECT #{columns.join ","} FROM #{table}
            WHERE id = #{id};
        SQL
 
        data = Hash[columns.zip(row)]
        new(data)
    end
    
    def find(*ids)
        for i in 0...ids.length do
            id = ids[i]
            if not(id.is_a? Integer) || id < 0
               raise ArgumentError.new("An id must be a nonnegative integer (id # #{i})")
            end
        end

        if ids.length == 1
            find_one(ids.first)
        else
            
            rows = connection.execute <<-SQL
                SELECT #{columns.join ","} FROM #{table}
                WHERE id IN (#{ids.join(",")});
            SQL
 
            rows_to_array(rows)
        end
    end
    
    def find_by(attribute, value)
        if not(attribute.is_a? String) and not(attribute.is_a? Symbol)
            raise ArgumentError.new("the first argument to 'find_by' must be a string or symbol")
        end
        row = connection.get_first_row <<-SQL
            SELECT #{columns.join ","} FROM #{table}
            WHERE #{attribute} = #{BlocRecord::Utility.sql_strings(value)};
        SQL
 
        init_object_from_row(row)
    end
    
    def take(num=1)
        if not(num.is_a? Integer) or num < 1
            raise ArgumentError.new("the argument to 'take' must be a positive integer")
        end
        if num > 1
            rows = connection.execute <<-SQL
                SELECT #{columns.join ","} FROM #{table}
                ORDER BY random()
                LIMIT #{num};
            SQL
 
            rows_to_array(rows)
        else
            take_one
        end
    end
    
    def take_one
        row = connection.get_first_row <<-SQL
            SELECT #{columns.join ","} FROM #{table}
            ORDER BY random()
            LIMIT 1;
        SQL
 
        init_object_from_row(row)
    end
    
    def first
        row = connection.get_first_row <<-SQL
            SELECT #{columns.join ","} FROM #{table}
            ORDER BY id ASC LIMIT 1;
        SQL
        init_object_from_row(row)
    end
 
    def last
        row = connection.get_first_row <<-SQL
            SELECT #{columns.join ","} FROM #{table}
            ORDER BY id DESC LIMIT 1;
        SQL
        init_object_from_row(row)
    end

    def all
        rows = connection.execute <<-SQL
            SELECT #{columns.join ","} FROM #{table};
        SQL
        rows_to_array(rows)
    end
 
    private
    def init_object_from_row(row)
        if row
            data = Hash[columns.zip(row)]
            new(data)
        end
    end
    
    def rows_to_array(rows)
        rows.map { |row| new(Hash[columns.zip(row)]) }
    end
    
    def find_each(start:, batch_size:)
        
        rows = connection.execute <<-SQL
            SELECT #{columns.join ","} FROM #{table}
            LIMIT #{batch_size} OFFSET #{start};
        SQL
        arr = rows_to_array(rows)
        arr.each do |row|
            yield(row)
        end
    end
    
    def find_in_batches(start:, batch_size:)
        
        offset = start
        batch_num = 0
        begin
            rows = connection.execute <<-SQL
                SELECT #{columns.join ","} FROM #{table}
                LIMIT #{batch_size} OFFSET #{offset};
            SQL
            arr = rows_to_array(rows)
            arr.each do |row|
                yield(row, batch_num)
            end
            offset = offset + batch_size
            batch_num = batch_num + 1
        end until arr.length < batch_size
    end
    
    def method_missing(m, *args, &block)
        m = m.to_s # m will be a symbol until coerced to a stringd
        # we want to handle the following case:
        # 1. the method name is of the form find_by_<attribute>, and
        # 2. there is exactly one argument, the value, and
        # 3. there is no block argument.
        # In that case, we convert to find_by(attribut, value)
        prefix = "find_by_"
        if m.start_with? prefix and args.length == 1 and not(block_given?)
            attribute = m[prefix.length..-1]
            value = args[0]
            return find_by(attribute, value)
        end
        # otherwise raise an exception
        raise NoMethodError("no method called: #{m}")
    end
end