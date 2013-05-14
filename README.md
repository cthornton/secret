Secret Files
============
Keeps your files more secure by ensuring saved files are chmoded 0700 by the same user who is running the process.
For example, this could be used by a Rails application to store certificates only readable by the www-data process.

The secret files gem includes some fun over-engineering with file locking!

## Usage
Add to your Gemfile:

```ruby
gem 'secret'
```

Now you should set up your "default" container in an initializer:

```ruby
Secret.configure_default 'path/to/secret/dir'
```

Finally, you should now be able to put stuff into the secret directory, or read contents!

```ruby
secret = Secret.default

# Save the key
secret.some_key.stash "ThisIsSomeKey"

# Get the key
puts secret.some_key.contents

# Manually seek through the file
secret.some_key.stream 'r' do |f|
    f.seek 1, IO::SEEK_CUR
end

# Support for nested directories
file = secret.file "certs/file.crt"
file.stash "Contents of CA File"
puts file.contents

# Also support for shorthand syntax
secret.stash "certs/file.key", "Contents of this key file!"
puts secret.contents "certs/file.key"
```

## Encryption
The secret gem supports basic AES encryption with a random [IV](http://en.wikipedia.org/wiki/Initialization_vector).
Note that encryption / decryption is somewhat slow and is intended only for small strings and files.

You should implement your own encryption mechanism for anything that is more comprehensive than basic passphrase encryption.

```ruby
secret = Secret.default
file   = secret.file "my_file.txt"

# Note here that unencrypted content touches the hard drive
file.stash "This is some secret contents"

if file.encrypted?
  puts "Encrypting file contents..."
  file.encrypt! "password"
  puts file.contents

  puts "Changing file passphrase..."
  file.change_encryption_passphrase! "password", "password2"
else
  puts "Decrypted file contents..."
  puts file.decrypted "password2"
  
  # Will still be an encrypted string
  puts file.contents
  
  # Decrypt the file
  puts "Decrypting file..."
  file.decrypt!
  puts file.contents
end

# If we immediately wish to stash some encrypted data
file = secret.file "file2.txt"
file.stash_encrypted "This is encrypted", "password"
```

## How Secure is It?
Ths is only *somewhat* secure and will provide protection against:

* Someone who gains access to your server with non-root access
* Other non-root server processes

However, this will **not** protect you against:

* People with root access
* Arbitrary code execution attacks by the owner (i.e. an `eval()` gone wrong)

## Other Features
This gem also includes locking support, meaning that it will be resillient against multiple processes
writing to a file. This will **not** lock multiple threads from the same process.