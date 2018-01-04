 require 'sqlite3'
 require 'bloc_record/utility'
 
 module Schema
    def table
        BlocRecord::Utility.underscore(name)
    end
    def schema
        unless @schema
            @schema = {}
            case BlocRecord.db_type
            when :sqlite3
                connection.table_info(table) do |col|
                    @schema[col["name"]] = col["type"]
                end
                return @schema
            when :pg
                rows = execute <<-SQL
                            SELECT *
                            FROM information_schema.columns
                            WHERE table_schema = 'public'
                            AND table_name   = '#{table}';
                        SQL
                
            end
        end
        @schema
    end
    
    def columns
        schema.keys
    end
    
    def attributes
        columns - ["id"]
    end
    
    def count
        connection.execute(<<-SQL)[0][0]
            SELECT COUNT(*) FROM #{table}
        SQL
    end
 end
 