module Secret

  # Handles file operations. Uses Ruby's internal file locking mechanisms.
  class File
    # include Secret::Encryption

    attr_reader :container, :identifier

    # Creates a new secret file. The specified identifier doesn't already need to exist.
    # @param [Secret::Container] container the container object
    # @param [Symbol] identifier an unique identifier for this container
    def initialize(container, identifier)
      raise ArgumentError, "Container must be a Secret::Container object" unless container.is_a?(Secret::Container)
      @container = container; @identifier = identifier
      touch!
      ensure_writeable!
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
    # @note Uses an exclusive lock on this file
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
    def stream(mode = 'r', &block)
      touch!
      ensure_writeable!
      return ::File.open(file_path, mode, container.chmod_mode)  unless block_given?
      ::File.open(file_path, mode, container.chmod_mode) do |f|
        begin
          f.flock(::File::LOCK_EX) # Lock with exclusive mode
          block.call(f)
        ensure
          f.flock(::File::LOCK_UN)
        end
      end
    end


    # Gets the contents of the file in a string format. Will return an empty string if the file doesn't exist, or the
    # file just so happens to be empty.
    # @return [String] the contents of the file
    def contents
      str = nil
      stream 'r' do |f|
        str = f.read
      end
      return str
    end


    # Creates a new file if it doesn't exist. Doesn't actually change the last updated timestamp.
    # @return [Boolean] true if an empty file was created, false if the file already existed.
    def touch!
      unless exist?
        ::File.open(file_path, 'w', container.chmod_mode) {}
        secure!
        return true
      end
      return false
    end

    # Secures the file by chmoding it to 0700
    # @raise [IOError] if the file doesn't exist on the server.
    def secure!
      raise IOError, "File doesn't exist" unless exist?
      ::File.chmod(container.chmod_mode, file_path)
    end


    # Stashes some content into the file! This will write a temporary backup file before stashing, in order to prevent
    # any partial writes if the server crashes. Once this finishes executing, you can be sure that contents have been
    # written.
    # @param [String] content the contents to stash. **Must be a string!**
    # @raise [ArgumentError] if content is anything other than a String object!
    def stash(content)
      raise ArgumentError, "Content must be a String (was type of type #{content.class.name})" unless content.is_a?(String)
      touch!
      ensure_writeable!
      
      # Think of this as a beginning of a transaction.
      ::File.open(file_path, 'a', container.chmod_mode) do |f|
        begin
          f.flock(::File::LOCK_EX)
  
          # Open a temporary file for writing, and close it immediately
          ::File.open(tmp_file_path, "w", container.chmod_mode){|f| f.write content }
  
          # Rename tmp file to backup file now we know contents are sane
          ::File.rename(tmp_file_path, backup_file_path)
          
          # Truncate file contents to zero bytes
          f.truncate 0
          
          # Write content
          f.write content
        ensure
          # Now unlock file!
          f.flock(::File::LOCK_UN)
        end
        
        # Delete backup file
        ::File.delete(backup_file_path)
      end

      # Committed! Secure it just in case
      secure!
    end
    
    def ensure_writeable!
      unless ::File.writable?(file_path)
        raise FileUnreadableError, "File is not writeable - perhaps it was created by a different process?"
      end
    end

    # Attempts to restore a backup (i.e. if the computer crashed while doing a stash command)
    # @return [Boolean] true if the backup was successfully restored, false otherwise
    def restore_backup!
      return false unless ::File.exist?(backup_file_path)
      
      # We know backup exists, so let's write to the file. We want to truncate file contents.
      # Now copy file contents over from the backup file. We use this method to use locking.
      ::File.open(file_path, 'w', container.chmod_mode) do |f|
        begin
          f.flock ::File::LOCK_EX
          ::File.open(backup_file_path, 'r', container.chmod_mode) do |b|
            f.write b.read
          end
        ensure
          f.flock ::File::LOCK_UN
        end
      end
      return true
  
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