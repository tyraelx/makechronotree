require digest
require securerandom

class Makechronotree
	
	private_class_method def makeRandomName()
		Digest::SHA256.hexdigest(Digest::SHA256.hexdigest(SecureRandom.hex(32)))
	end

	private_class_method def setPermissionsAndOwner()
		system "chown -R backupmaster:backupmaster #{BPATH_CONST}" 
    	system "chmod -R 755 #{BPATH_CONST}"
	end

	private_class_method def run(args)
    	bpath = args['bpath']
    	name = args['name']

    	topname = BPATH_CONST + name
    	if(!Dir.exist?(topname) and !File.exist?(topname))
        	system "mkdir '#{topname}'"
    	end

    	conflict = topname + "/conflict" 
    	if(!Dir.exist?(conflict))
        	system "mkdir '#{conflict}'"
    	end

    	if(args['path'].nil?)
        	path = []
        	cpath = bpath
    	else
        	path = args['path']

        	cpath = bpath + path.join("/") + '/'
    	end

    	if(!path.empty?)
        	subtopname = BPATH_CONST + name + '/' + path.join('/')
        	if(!Dir.exist?(subtopname) and !File.exist?(subtopname))
            	system "mkdir '#{subtopname}'"
        	end
    	end

    	ls = Dir.entries(cpath)
    	ls.delete_if do |fil| fil.match(/(^\.$|^\.\.$|\.tacitpart$)/) end
        	
    	ls.each do |fil|

        	if(File.directory?(cpath + fil))
            	nypath = path.clone
            	nypath.push(fil)
            	processPath({'bpath' => bpath, 'name' => name, 'path' => nypath})
            	next
        	end

        	extension = /(.*)(\.[a-zA-Z0-9]{2,4})$/.match(fil)

        	grab = cpath + fil

        	if(path.empty?)
            	to = BPATH_CONST + name + "/"
        	else
            	to = BPATH_CONST + name + "/" + path.join("/") + "/"
        	end

        	if(File.exist?(to + fil))
            	diff = system "diff '#{to + fil}' '#{grab}' > /dev/null"
            	if(diff == true)
                	to = conflict + '/' 
            	end
        	end

        	number = 1
        	while(File.exist?(to + fil)) do
             	 number += 1
             	 fil = extension[1] + '-col' + number.to_s + extension[2]
        	end

        	if(!File.exist?(grab))
            	next
        	end

        	#############system "cp '#{grab}' '#{to + fil}'"
        	#############system "rm '#{grab}'"        
        	system "mv '#{grab}' '#{to + fil}'"

    	end

		self.setPermissionsAndOwner()
	end
end
