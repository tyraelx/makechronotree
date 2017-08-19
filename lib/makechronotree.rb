require 'date'
require 'time'
require 'digest'
require 'mini_exiftool'
require 'fileutils'

class Makechronotree

	def self.start(targetPath, destinationPath, origin = nil)
		targetPath = self::validatePath(targetPath, true)
		destinationPath = self::validatePath(destinationPath)

		if(!targetPath)
			self.log('Error: Invalid target.')
			exit
		elsif(!destinationPath)
			self.log('Error: Invalid destination')
			exit
		end

		makechronotree = self.new(targetPath, destinationPath, origin)
 	end

	def self.log(msg)
		puts "#{msg}\n"
	end
	
	def initialize(targetPath, destinationPath, origin = nil)
		@targetPath = targetPath
		@destinationPath = destinationPath
		@db = Db.new(destinationPath)
		@origin = @db.createOrGetOrigin(origin)

		traversePath()
	end 

	private

		def self.validatePath(path, isTarget = false, create = nil)
			path = path.gsub(/[\/]{2,}/, '/')
			isRoot = path.slice(0) == '/'

			if(isRoot)
				path.slice!(0)
			end

			path = path.split('/')
			
			path.reverse_each do |p|
				if(p == nil || p.empty? || p.match(/^\s*$/))
					path.delete(p)
				end
			end

			buildPath = isRoot ? '/' : ''

			path.each do |p|
				buildPath += (buildPath == '' || buildPath == '/' ? '' : '/') + p

				if(!Dir.exist?(buildPath))
					if(create || (!isTarget && p.equal?(path.last)))
						Dir.mkdir(buildPath)
						self::setPermissions(buildPath)
					else
						return false
					end
				end
			end

			path = buildPath

			return path
		end

	 	def self.setPermissions(pathToFile)
			File.chmod(0755, pathToFile)
		end
		
		def traversePath(path = nil)
			if(!path)
				noArgument = 1
				path = @targetPath
			end
		
			ls = Dir.entries(path)

    		ls.delete_if do |entry| 
    			entry.match(/(^\.|^\.\.)$/)
    		end

    		if(ls.empty?)
    			if(!noArgument)
					Dir::rmdir(path)
    			end

				return
    		end

    		ls.delete_if do |entry| 
    			entry.match(/(^\.|^\.\.|\.tacitpart|\.part|\.tmp|\.log)$/)
    		end
        		
    		ls.each do |entry|
    			pathToEntry = path + '/' + entry
        		if(File.directory?(pathToEntry))
            		traversePath(pathToEntry)
            	else
					processFile(pathToEntry)
        		end
        	end
		
		end

		def getFilename(pathToFile)
			return pathToFile.split('/').last
		end

		def splitFilenameAndExtension(filename)
			extension = /\.[a-zA-Z0-9]{2,4}$/.match(filename)[0]
			
			return {name: filename.chomp(extension), extension: extension}
		end

		def makeFilenameFromDate(date)
			return date.strftime('%Y-%m-%d_%H%M%S') 
		end

		def getDate(pathToFile)
			filename = getFilename(pathToFile)
		
			begin
				exif = MiniExiftool.new(pathToFile)

				if(exif.createDate && exif.createDate.instance_of?(Time))
					if(!date || date > exif.createDate)
						date = exif.createDate
					end
				end

				if(exif.fileModifyDate && exif.fileModifyDate.instance_of(Time))
					if(!date || date > exif.fileModifyDate)
						date = exif.fileModifyDate
					end	
				end
			rescue
			end

			fileCreationDate = File.ctime(pathToFile)

			if(!date || date > fileCreationDate)
				date = fileCreationDate
			end

			fileModificationDate = File.mtime(pathToFile)

			if(!date || date > fileModificationDate)
				date = fileModificationDate
			end

			dateFromFilename = splitFilenameAndExtension(filename)[:name].match(/([^\d]|^)(\d{4}(([\-\_\.\s]|)\d{2}){2}[\-\_\.\s]\d{2}(([\-\_\.\s]|)\d{2}){2})([^\d]|$)/)

			if(dateFromFilename)
				dateFromFilename = dateFromFilename[2].gsub(/[^\d]/, '')
				timezone = DateTime.now.zone.gsub(':', '')

				begin
					dateFromFilename = DateTime.parse(dateFromFilename + timezone)
				rescue
					dateFromFilename = nil
				end

				if(dateFromFilename)
					dateFromFilename = dateFromFilename.to_time
					
					if(date > dateFromFilename && (date.year - dateFromFilename.year).between?(0,15))
						date = dateFromFilename
					end
				end
			end
			
			return date
		end

		def fileGetChecksumAndValidate(pathToFile)
			checksum = Digest::MD5.file(pathToFile).hexdigest
			get = @db.checksumExists(checksum)
			matchFound = nil
			
			if(get)
				get.each do |item|
					file = getFilePathFromDate(DateTime.parse(item['created_at'])) + '/' + item['name']
					
					if(FileUtils.compare_file(pathToFile, file))
						matchFound = 1

						puts "Conflict: #{file}"

						break
					end
				end
			end

			if(matchFound)
				return nil
			end

			return checksum
		end

		def getMonthName(monthNumber)
			months = ['Januar', 'Februar', 'Mars', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Desember']

			return months[monthNumber - 1]
		end

		def getFilePathFromDate(date)
			return [@destinationPath, date.year, getMonthName(date.month)].join('/')
		end

		def alert(pathToFile, msg)
			puts "#{pathToFile}: " + msg
		end

		def processFile(pathToFile)
			date = getDate(pathToFile)
			checksum = fileGetChecksumAndValidate(pathToFile)
			newPath = getFilePathFromDate(date)
			extension = splitFilenameAndExtension(getFilename(pathToFile))[:extension]
			filename = makeFilenameFromDate(date)
			finalFilename = filename + extension

			if(!checksum)
				alert(pathToFile, 'File already exists, omitting/removing..')
				removeFile(pathToFile)

				return
			end

			self.class::validatePath(newPath, false, true)
			    		
        	number = 0
        	while(File.exist?(newPath + '/' + finalFilename)) do
             	 number += 1
             	 finalFilename = filename + '-' + number.to_s + extension
        	end

        	if(!File.exist?(pathToFile))
        		alert(pathToFile, 'File disappeared while processing..')

            	return
        	end

			move = moveFile(pathToFile, newPath + '/' + finalFilename)

			if(move.instance_of?(String))
				alert(pathToFile, move)
			elsif(!move)
				alert(pathToFile, "Something went wrong while moving to final destination, #{newPath + "/" + finalFilename}")
			else
				@db.createFile(finalFilename, checksum, date, @origin)
			end
		end

		def moveFile(pathToSource, pathToDestination)
			if(!File.exist?(pathToSource))
				return 'Source file not found.'
			elsif(File.exist?(pathToDestination))
				return "Destination filename already exists, #{pathToDestination}"
			end

			FileUtils.mv(pathToSource, pathToDestination)

			self.class::setPermissions(pathToDestination)

			return true
		end

		def removeFile(pathToFile)
			if(!File.exist?(pathToFile))
				return nil
			end

			File.delete(pathToFile)

			return true
		end

end
