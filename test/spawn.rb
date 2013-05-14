require 'rubygems'
require 'bundler/setup'
require 'secret'
Secret.configure_default 'secrets'
container = Secret.default

f = "running.txt"
File.open(f, 'w'){|f| f.write "Running..." }

container.test1.stream 'w' do |f|
  puts "Sleeping for 10 seconds..."
  sleep(10)
  f.write "New Contents"
end

File.delete(f)