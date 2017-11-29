## Questions for Checkpoint-2: Create and ORM

### What's a RubyGem and why would you use one?

A Ruby Gem is a self-contained Ruby package containing a program or a library of related programs that can be imported into your program.

Gems are a convenient way to share code between different programs. So any time that you create functionality that might be useful in more
than one program, Gems is a good way to promote the reuse of that code.

### What's the difference between lazy and eager loading?

In eager loading, imported programs are loaded right away. In lazy loading, imported programs are only loaded right before they are needed (right before
functions from those programs are called).

### What's the difference between the CREATE TABLE and INSERT INTO SQL statements?

`CREATE TABLE` creates an initially empty table, with the specified column names and types (as well as constraints such as a column being a primary key). `INSERT INTO`, in contrast, assumes that the table already exists, and adds one or more rows to the table.

### What's the difference between extend and include? When would you use one or the other?

When you create a module that contains a function definition, there are two ways to use this function in a new Ruby class:
1. When you `extend` the module, you add the module's methods as class methods of the new class.
2. When you `include` the module, you add the module's methods as instance methods of objects of the new class.

### In persistence.rb, why do the save methods need to be instance (vs. class) methods?

An instance method is able to access state information found in the instance. In contrast, a class method cannot access instance data. When you save
a model, it is of course, important that you save state information, so you need an instance method.

### Given the Jar-Jar Binks example earlier, what is the final SQL query in persistence.rb's save! method?
```
       UPDATE character 
       SET character_name = 'Jar-Jar Binks', star_rating = 1
       WHERE id = 7;
```
(Instead of `7`, it will be whatever id was used for the initial creation of the `Jar-Jar Binks` row).

### AddressBook's entries instance variable no longer returns anything. We'll fix this in a later checkpoint. What changes will we need to make?

In the old implementation of AddressBook, the variable `entries` was an array of address book entries. In the new implementation, the data will be kept in a database table, instead. It seems to me that there are two options:
1. Rewrite the code for Addressbook so that the variable `entries` is never directly accessed, but instead there are methods for inserting and searching the entries.
2. ALternatively, we can initialize `entries` by running an SQL query to get all the data.

I assume that the second is preferrable, because we want to make as little change to the AddressBook code as possible?

### Write a Ruby method that converts snake_case to CamelCase using regular expressions (you can test them on Rubular). Send your code to your mentor.

```
def snake_to_camel(x)
    pattern = /((\A(([a-zA-Z0-9])+))|((?<=_)(([a-zA-Z0-9])+)))/ # This matches either an alphanumeric substring at the beginning 
                                                                # or an alphanumerica substring immediately after a '_'
    retval = ""
    x.gsub(pattern) do |m|
        retval = retval + m.capitalize
    end
    return retval
end
```
**Example output**
```
2.4.0 :201 > snake_to_camel("apple_brown_betty")
 => "AppleBrownBetty" 
2.4.0 :202 > 
```
### Add a select method which takes an attribute and value and searches for all records that match:

> Assuming you have an AddressBook, it might get called like this:
> 
> myAddressBook = AddressBook.find_by("name", "My Address Book")
> 
> Your code should use a SELECT…WHERE SQL query and return an array of objects to the caller. Send your code to your mentor.

```
lib/bloc_record/selection.rb

    def find_by(attribute, value)
        row = connection.get_first_row <<-SQL
            SELECT #{columns.join ","} FROM #{table}
            WHERE #{attribute} = '#{value}';
        SQL
 
        data = Hash[columns.zip(row)]
        new(data)
    end
```

