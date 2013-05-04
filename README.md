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
    secret.some_key.stream do |f|
        f.seek 1, IO::SEEK_CUR
    end
    ```

## How Secure is It?
Ths is only *somewhat* secure and will provide protection against:

* Someone who gains access to your server with non-root access
* Other non-root server processes

However, this will **not** protect you against:

* People with root access
* Arbitrary code execution attacks by the owner (i.e. an `eval()` gone wrong)

## Other Features
This gem also includes locking support, meaning that it should (hopefully) be resillient against multiple processes
writing to a file. The primary reason for this is because I really wanted to try file locking. However, don't do
anything too tricky and you should be okay.