require 'rubygems'
require 'bundler/setup'

require 'secret'

Secret.configure_default 'secrets'

container = Secret.default
container.cert_key.stash "Hello World!"
puts container.cert_key.encrypt_basic "password"