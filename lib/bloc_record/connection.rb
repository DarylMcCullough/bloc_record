require 'sqlite3'
 
module Connection
    def connection
        case BlocRecord.db_type
        when :sqlite3
            @connection ||= SQLite3::Database.new(BlocRecord.database_filename)
            return @connection
        when :pg
            if BlocRecord.pass != nil
                @connection ||= PG.connect :dbname => BlocRecord.dbname, :user => BlocRecord.user,  
                    :password => BlocRecord.pass
            else
                @connection ||= PG.connect :dbname => BlocRecord.dbname, :user => BlocRecord.user
            end
            return @connection
        end
    end
    
    def execute(args)
        case BlocRecord.db_type
        when :sqlite3
            return connection.execute(args)
        when :pg
            rows = connection.exec(args)
            return rows.values()
        end
    end
    
    def get_first_row(args)
        case BlocRecord.db_type
        when :sqlite3
            return connection.get_first_row(args)
        when :pg
            results = execute(args)
            return results.first
        end
    end
end