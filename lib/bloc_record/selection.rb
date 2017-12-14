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

        if row == nil
            return nil
        end
        
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
    
    def where(*args)
        if args.count == 0
            where_clause = ";"
        else
            if args.count > 1
                expression = args.shift
                params = args
            else
                case args.first
                when String
                    expression = args.first
                when Hash
                    expression_hash = BlocRecord::Utility.convert_keys(args.first)
                    expression = expression_hash.map {|key, value| "#{key}=#{BlocRecord::Utility.sql_strings(value)}"}.join(" and ")
                end
            end
            where_clause = "WHERE #{expression};"
        end

        sql = <<-SQL
            SELECT #{columns.join ","} FROM #{table}
            #{where_clause}
        SQL

        rows = connection.execute(sql, params)
        rows_to_array(rows)
    end

    
    def order(*args, **kwargs)
        arglist = []
        args.each do |arg|
            case arg
            when String # either "name" or "name asc" or ...
                parts = arg.split()
                begin
                    key = parts[0] # for example, "name"
                    direction = get_order_direction(parts[1..-1]) # interpret the rest of the string as a direction, "asc" or "desc"
                    value = key + " " + direction
                    arglist.push(value)
                rescue
                    raise ArgumentError.new("the argument to 'order' not understood: #{arg}")
                end
            when Symbol
                key = arg.to_s
                direction = 'ASC' # the default
                value = key + " " + direction
                arglist.push(value)
                next
            end
            raise ArgumentError.new("the argument to 'order' not understood: #{arg}")
        end
        kwargs.each do |key, value| # pairs of the form name: :asc, etc.
            key = key.to_s
            direction = get_order_direction([value])
            value = key + " " + direction
            arglist.push(value)
            next
        end
        order = arglist.join(",")

        rows = connection.execute <<-SQL
            SELECT * FROM #{table}
            ORDER BY #{order};
        SQL
        rows_to_array(rows)
    end
    
    def join(*args, **kwargs)
        # The first args are interpreted as table names.
        # It is assumed that each table that uses foreign keys
        # has a key of the form <foreign_table>_id.
        # So we are joining the tables on <this_table>.id = <that_table>.<this_table>_id
        
        # The kwargs are interpreted as pairs of table names.
        # We are joing the first with <this_table> on <this_table>.id = <first_table>.<this_table>_id
        # But we are joiningthe second with <first_table>.id = <second_table>.<first_table>_id
        
        if args.count + kwargs.count > 1
            joins = get_join_statement(table, *args, **kwargs) #see below
            rows = connection.execute <<-SQL
                SELECT * FROM #{table} #{joins}
            SQL
        else
            case args.first
            when String
                rows = connection.execute <<-SQL
                    SELECT * FROM #{table} #{BlocRecord::Utility.sql_strings(args.first)};
                SQL
            when Symbol
                rows = connection.execute <<-SQL
                    SELECT * FROM #{table}
                    INNER JOIN #{args.first} ON #{args.first}.#{table}_id = #{table}.id
                SQL
            end
        end
 
        rows_to_array(rows)
    end
    
    private
    
    def get_join_statement(table, *args, **kwargs)
        # The first args are interpreted as table names.
        # It is assumed that each table that uses foreign keys
        # has a key of the form <foreign_table>_id.
        # So we are joining the tables on <this_table>.id = <that_table>.<this_table>_id
        
        # The kwargs are interpreted as pairs of table names.
        # We are joing the first with <this_table> on <this_table>.id = <first_table>.<this_table>_id
        # But we are joiningthe second with <first_table>.id = <second_table>.<first_table>_id
        
        join_ids = {}
        args.each do |arg|
            join_ids[arg] = table
        end 

        kwargs.each do |table1, table2|
            join_ids[table1] = table
            join_ids[table2] = table1
        end
        
		result = join_ids.map do |table_name, table_to_join|
		    "INNER JOIN #{table_name} ON #{table_name}.#{table_to_join}_id = #{table_to_join}.id"
		end
		result = result.join(" ")
        return result
    end

    def get_order_direction(args)
        if args.length == 0
            return 'ASC' # no arguments, use the default
        end
        if args.length == 1 # one argument, should be asc or desc
            arg = args[0].to_s.upcase
            if ['ASC', 'DESC'].include? arg
                return arg
            end
        end
        raise ArgumentError.new("not a direction: #{args.join(' ')}")
    end
    
    def init_object_from_row(row)
        if row
            data = Hash[columns.zip(row)]
            new(data)
        end
    end
    
    def rows_to_array(rows)
        rows.map { |row| new(Hash[columns.zip(row)]) }
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