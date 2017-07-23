Gem::Specification.new do |s|
	s.name = 'makechronotree'
	s.version = '0.1'
	s.date = '2017-04-07'
	s.description = 'Copy files into chronological filetree sorted into years and months.'
	s.summary = 'Copy files into chronological filetree.'
	s.authors = ['Roy Hansen']
	s.email = 'roy@hansenroy.com'
	s.files = ['lib/db.rb', 'lib/makechronotree.rb']
	s.executables << 'makechronotree'
	s.license = 'MIT'
	s.add_dependency('OptionParser')
	s.add_dependency('mini_exiftool')
	s.add_dependency('sqlite3')
	s.add_dependency('digest')
end
