require 'rubygems'
require 'bundler/setup'
require 'win32/process'

require 'secret'

Secret.configure_default 'secrets'

container = Secret.default

f = container.file("path/to/file")
f.stash "Hello World!"

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