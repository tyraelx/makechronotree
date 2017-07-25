require 'sqlite3'

class Db

	def initialize(destinationPath)
    	dbFile = destinationPath + '/db.sqlite3'
			
		new = nil
		if(!File.file?(dbFile))
			new = true
		end

		@db = SQLite3::Database.new(dbFile)
		
		@db.results_as_hash = true

		if(new)
			createTables()
		end

		return self
	end 

	def createOrGetOrigin(name)
		if(!name || !name.instance_of?(String) || name.strip == "")
			return nil
		end

		name = name.strip

		id = @db.get_first_value("select id from origin where lower(name) = ? order by id limit 1", name.downcase)

		if(!id)
			@db.prepare("insert into origin (name) values (?)").execute(name)
			id = @db.last_insert_row_id
		end

		return id
	end

	def checksumExists(checksum)
		return @db.prepare("select name, created_at from file where checksum = ?").execute(checksum)
	end

	def createFile(name, checksum, created_at, origin = nil)
		@db.prepare("insert into file (name, checksum, created_at, origin) values (?, ?, ?, ?)").execute(name, checksum, created_at.strftime('%Y-%m-%d %H:%M:%S'), origin)
	end

	private

		def createTables
			@db.execute("create table file (id integer primary key autoincrement, name varchar(40), checksum varchar(32), created_at datetime, origin tinyint(3))")

			@db.execute("create table origin (id integer primary key autoincrement, name varchar(255), description text)")
		end 

end
