module BlocRecord
   
    def self.connect_pg(**kwargs)
        @user = kwargs[:user]
        @dbname = kwargs[:dbname]
        @pass = nil
        if **kwargs.key? :pass
            @pass = kwargs[:pass]
        end
        @db_type = :pg
    end
    
    def self.connect_sqlite(filename:)
        @database_filename = filename
        @db_type = :sqlite3
    end
  
    def self.connect_to(args, db_type)
        case db_type.to_s
        when "pg"
            args = self.parse_pg_args(args)
            self.connect_pg(**args)
            return
        when "sqlite3"
            self.connect_sqlite(args)
            return
        else
            raise ArgumentError.new("'connect_to': database type not understood: #{db_type}")
        end
    end
 
    def self.database_filename
        @database_filename
    end
    
    private
    def self.parse_pg_args(args)
        if not(args.is_a? String)
            raise ArgumentError.new("the argument to 'connect_to' must be a string")
        end
        # assuming args is something of the sort
        # A: B, C: D, ...
        associations = args.split(",")
        args = {}
        associations.each do |association|
            key_value = association.split()
            if key_value.length != 2
                raise ArgumentError.new("the associations in 'connect_to' must be of the form 'key1: value1, key2: value2...'")
            end
            key = key_value[0].to_sym
            value = key_value[1]
            args[key] = value
        end
        if not(args.key? :dbname)
            raise ArgumentError.new("'connect_to': must supply a database name")
        end
        if not(args.key? :user)
            raise ArgumentError.new("'connect_to': must supply a user name")
        end
        keys = args.keys
        keys.each do |key|
            if key != :dbname and key != :user and key != :pass
                raise ArgumentError.new("'connect_to': unexpected keyword: '#{key}'")
            end
        end
        return args
    end
end