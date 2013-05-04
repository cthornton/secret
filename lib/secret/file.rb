module Secret

  # Handles file operations.
  #
  # Note that locking operations are not perfect!
  class File
    include Secret::Locking

    # include Secret::Encryption

    attr_reader :container, :identifier

    # Lock timeout in MS. Defaults to 5000 MS
    attr_accessor :lock_timeout_ms

    # Whether this current object holds the lock over the file.
    # @return [Boolean] TRUE if this object was the one that holds the lock (i.e. created the lock), FALSE if another
    #   object holds the lock, or the file simply isn't locked.
    attr_reader :owns_lock

    # Creates a new secret file. The specified identifier doesn't already need to exist.
    # @param [Secret::Container] container the container object
    # @param [Symbol] identifier an unique identifier for this container
    def initialize(container, identifier)
      raise ArgumentError, "Container must be a Secret::Container object" unless container.is_a?(Secret::Container)
      @container = container; @identifier = identifier; @owns_lock = false
      @lock_timeout_ms = Secret::Locking::DEFAULT_LOCK_WAIT_MS
    end

    # Checks whether this file actually exists or not
    # @return [Boolean] true if the file exists (i.e. has content), false if otherwise.
    def exist?
      ::File.exist?(file_path)
    end

    # Gets a file stream of this file. If the file doesn't exist, then a blank file will be created. By default,
    # this allows you to write to the file. However, please use the {#stash} command, as it accounts for mid-write
    # crashes. Don't forget to close the file stream when you're done!
    # @param [String] mode the mode for this file. Currently defaults to 'r+', which is read-write, with the
    #   file pointer at the beginning of the file.
    # @return [IO] an IO stream to this file, if not using a block
    # @note This completely bypasses any internal locking mechanisms if not using a block!
    # @example
    #     file = container.some_file
    #
    #     # Unsafe way!
    #     io = file.stream
    #     io.write "Hello World!"
    #     io.close
    #
    #     # Safe way, with locking support
    #     file.stream do |f|
    #       f.write "Hello World!"
    #     end
    def stream(mode = 'r+', &block)
      touch!
      return ::File.open(file_path, mode, Secret::CHMOD_MODE)  unless block_given?
      wait_for_unlock(true, lock_timeout_ms) do
        io = ::File.open(file_path, mode, Secret::CHMOD_MODE)
        block.call(io)
        io.close unless io.closed?
      end
    end


    # Gets the contents of the file in a string format. Will return an empty string if the file doesn't exist, or the
    # file just so happens to be empty.
    # @return [String] the contents of the file
    def contents
      wait_for_unlock(false, lock_timeout_ms) do
        io = stream
        str = io.read
        io.close
      end
      return str
    end


    # Creates a new file if it doesn't exist. Doesn't actually change the last updated timestamp.
    # @return [Boolean] true if an empty file was created, false if the file already existed.
    def touch!
      unless exist?
        ::File.open(file_path, 'w') {}
        secure!
        return true
      end
      return false
    end

    # Secures the file by chmoding it to 0700
    # @raise [IOError] if the file doesn't exist on the server.
    def secure!
      raise IOError, "File doesn't exist" unless exist?
      ::File.chmod(Secret::CHMOD_MODE, file_path)
    end


    # Stashes some content into the file! This will write a temporary backup file before stashing, in order to prevent
    # any partial writes if the server crashes. Once this finishes executing, you can be sure that contents have been
    # written.
    # @param [String] content the contents to stash. **Must be a string!**
    # @raise [ArgumentError] if content is anything other than a String object!
    def stash(content)
      raise ArgumentError, "Content must be a String (was type of type #{content.class.name})" unless content.is_a?(String)

      # Get an exclusive lock
      wait_for_unlock(true, lock_timeout_ms) do
        touch!

        # Think of this as a beginning of a transaction.

        # Open a temporary file for writing, and close it immediately
        ::File.open(tmp_file_path, "w", Secret::CHMOD_MODE){|f| f.write content }

        # Rename the existing file path
        ::File.rename(file_path, backup_file_path)

        # Now rename the temporary file to the correct file
        ::File.rename(tmp_file_path, file_path)

        # Delete the backup
        ::File.delete(backup_file_path)

        # Committed! Secure it just in case
        secure!
      end
    end

    # Attempts to restore a backup (i.e. if the computer crashed while doing a stash command)
    # @return [Boolean] true if the backup was successfully restored, false otherwise
    def restore_backup!
      return false if locked?
      return false unless ::File.exist?(backup_file_path)

      # Ideally we want to get an exclusive lock when doing this!
      wait_for_unlock(true, lock_timeout_ms) do
        # If the file actually exists, then the backup file probably wasn't deleted, so just
        # delete the backup file.
        if ::File.exist?(file_path)
          ::File.delete(backup_file_path)
          return true

        # Otherwise, the temporary file probably wasn't renamed, so restore the backup and delete the temporary file
        # if it exists. It's possible the file was corrupted in the middle of writing, so it is better to resort
        # to an old and complete file rather than a new and possibly corrupted file.
        else
          ::File.rename(backup_file_path, file_path)
          ::File.delete(tmp_file_path) if ::File.exist?(tmp_file_path)
          return true
        end
      end
    end

    protected

    # Gets the path of the lock file
    def lock_file_path
      return file_path + '.lock'
    end


    private

    # Gets the actual file path of this container. Intentionally made private (security through obscurity)
    # @return [String] the absolute path to where this file is
    def file_path
      @the_file_path = ::File.join(container.directory, identifier.to_s) if @the_file_path.nil?
      return @the_file_path
    end

    # The path of the temporary file. Used as a temporary container for stashing. This file will then be re-named.
    # @return [String] the path to the temporary file
    def tmp_file_path
      return file_path + ".tmp"
    end

    # Gets the path of the backup file
    # @return [String] the path of the backup file
    def backup_file_path
      return file_path + '.bak'
    end




  end
end