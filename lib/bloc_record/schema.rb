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
                # https://dba.stackexchange.com/questions/22362/how-do-i-list-all-columns-for-a-specified-table
                # https://www.postgresql.org/docs/current/static/infoschema-columns.html
                rows = execute <<-SQL
                            SELECT *
                            FROM information_schema.columns
                            WHERE table_schema = 'public'
                            AND table_name   = '#{table}';
                        SQL
                arr = rows_to_array(rows)
                arr.each do |row|
                    @schema[row["column_name"]] = row["data_type"]
                end
                return @schema
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
        execute(<<-SQL)[0][0]
            SELECT COUNT(*) FROM #{table}
        SQL
    end
 end
 