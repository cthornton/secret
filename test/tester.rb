require 'rubygems'
require 'bundler/setup'
# require 'win32/process'

require 'secret'

Secret.configure_default 'secrets'
container = Secret.default

file = container.file "key.crt"
#file.delete!
unless file.encrypted?
  puts "Encrypting contents of file..."
  file.stash_encrypted "This is some secret text!", "password"
  puts "File contents: #{file.contents}"
  
  puts "Changing passphrase..."
  file.change_encryption_passphrase! "password", "password2"
  
  # puts "This should result in an error..."
  puts file.contents
else
  puts "Decrypting file contents..."
  file.decrypt! "password2"
  puts "Decrypted contents: " + file.contents
end




exit(0)
container.something.stash "My Secret Text!"
container.file(:someting_else).stash "More secret text"
container.dir('test')

puts "Testing some multi-process action"
container.test1.stash "Original Content"

# Windows - testing file locking
p = Process.create(
  :app_name => 'ruby spawn.rb',
  :creation_flags   => Process::DETACHED_PROCESS,
  :process_inherit  => false,
  :thread_inherit   => true,
)

sleep(1)
puts p.inspect

puts "New contents:"
puts "'#{container.test1.contents}'"