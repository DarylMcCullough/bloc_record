require 'sqlite3'
require 'bloc_record/schema'
 
module Persistence
    def self.included(base)
        base.extend(ClassMethods)
    end
    
    def save
        self.save! rescue false
    end
    
    def save!
        unless self.id
            self.id = self.class.create(BlocRecord::Utility.instance_variables_to_hash(self)).id
            BlocRecord::Utility.reload_obj(self)
            return true
        end
        
        fields = self.class.attributes.map { |col| "#{col}=#{BlocRecord::Utility.sql_strings(self.instance_variable_get("@#{col}"))}" }.join(",")
 
        self.class.connection.execute <<-SQL
            UPDATE #{self.class.table}
            SET #{fields}
            WHERE id = #{self.id};
        SQL
 
        true
    end
    
    def update_attribute(attribute, value)
        self.class.update(self.id, { attribute => value })
    end
    
    def update_attributes(updates)
        self.class.update(self.id, updates)
    end
    
    def method_missing(m, *args, &block)
        m = m.to_s # m will be a symbol until coerced to a stringd
        # we want to handle the following case:
        # 1. the method name is of the form update_<attribute>, and
        # 2. there is exactly one argument, the value, and
        # 3. there is no block argument.
        # In that case, we convert to update_attribute(attribute, value)
        prefix = "update_"
        if m.start_with? prefix and args.length == 1 and not(block_given?)
            attribute = m[prefix.length..-1]
            value = args[0]
            update_attribute(attribute, value)
            return true
        end
        # otherwise raise an exception
        raise NoMethodError("no method called: #{m}")
    end

    module ClassMethods
        def create(attrs)
            attrs = BlocRecord::Utility.convert_keys(attrs)
            attrs.delete "id"
            vals = attributes.map { |key| BlocRecord::Utility.sql_strings(attrs[key]) }
            puts("attributes: #{attributes}")
 
            sql = <<-SQL
                INSERT INTO #{table} (#{attributes.join ","})
                VALUES (#{vals.join ","});
            SQL
            
            puts sql
            
            connection.execute sql
 
            data = Hash[attributes.zip attrs.values]
            data["id"] = connection.execute("SELECT last_insert_rowid();")[0][0]
            new(data)
        end
        
        def update_all(updates)
            update(nil, updates)
        end
        
        def update(ids, updates)
            # We have four cases:
            # (1) if ids == nil, then we want to apply updates to every record
            # (2) if ids is a single integer, then we apply the updates to a single record
            # (3) if ids is an array of integers, and updates is a Hash,
            # then we apply those updates to every record in the set specified by the ids
            # (4) if ids is an array of integers, and updates is an array of Hashes,
            # then we apply the corresponding update to each record.
            
            if ids == nil # case 1
                update_multiple(nil, updates)
                return true
            end
            
            if ids.is_a? Integer # case 2
                update_multiple([ids], updates)
                return true
            end

            if ids.is_a? Array
                if updates.is_a? Hash # case 3
                    update_multiple(ids, updates)
                    return true
                end
                # case 4
                if not(updates.is_a? Array) or ids.length != updates.length
                    raise ArgumentError.new("In 'update', must provide equal numbers of updates and ids")
                end
                (0...ids.length).each do |i|
                    id = ids[i]
                    if not (id.is_a? Integer) or id < 0
                        raise ArgumentError.new("In 'update', ids must be nonnegative integers")
                    end
                    update = updates[i]
                    if not (update.is_a? Hash) 
                        raise ArgumentError.new("In 'update', updates must be Hashes")
                    end
                end
                (0...ids.length).each do |i|
                    id = ids[i]
                    update = updates[i]
                    update_multiple([id], update)
                end
                return true
            end
            raise ArgumentError.new("In 'update', must provide a Hash of updates for each id")
        end
        
        private
        
        # auxiliary method: calls updates on the records corresponding to ids
        # listed, or all records if ids is nil.
        def update_multiple(ids, updates)
            if ids != nil and not(ids.is_a? Array)
                raise ArgumentError.new("In 'update_multiple', must provide an array of ids")
            end
            if not(updates.is_a? Hash)
                raise ArgumentError.new("In 'update_multiple', must provide a hash of updates")
            end
            if ids != nil
                ids.each do |id|
                    if (not (id.is_a? Integer) or id < 0)
                        raise ArgumentError.new("In 'update_multiple', each id must be nil or a nonnegative integer")
                    end
                end
            end
            
            if ids == nil
                where_clause = ";"
            elsif ids.length == 1
                where_clause = "WHERE id = #{ids[0]};"
            else
                where_clause = ids.empty? ? ";" : "WHERE id IN (#{ids.join(",")});"
            end
            
            updates.delete "id"
            updates_array = updates.map { |key, value| "#{key}=#{BlocRecord::Utility.sql_strings(value)}" }
            connection.execute <<-SQL
                UPDATE #{table}
                SET #{updates_array * ","} #{where_clause}
            SQL
        end
    end
end