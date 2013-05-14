module Secret
  class Container

    attr_reader :directory, :files, :chmod_mode

    # Initializes a container. Does significant checking on the directory to ensure it is writeable and it exists.
    # @param [String] directory the directory to the container
    # @param [Boolean] auto_create if true, will attempt to create the directory if it does not exist.
    def initialize(directory, auto_create = true, chmod = Secret::CHMOD_MODE)
      @directory = directory
      @chmod_mode = chmod

      @files = {}

      # Do some checking about our directory
      if ::File.exist?(directory)
        raise ArgumentError, "Specified directory '#{directory}' is actually a file!" unless ::File.directory?(directory)

      # Now make our directory if auto_create
      else
        raise ArgumentError, "Specified directory '#{directory}' does not exist!" unless auto_create
        FileUtils.mkdir_p(directory, :mode => chmod_mode) # Only give read/write access to this user
      end
      raise ArgumentError, "Directory '#{directory}' is not writeable!" unless ::File.writable?(directory)
    end
    
    # Stashes the contents of a file
    def stash(path, contents)
      file(path).stash(contents)
    end
    
    def contents(path)
      file(path).contents
    end

    # Gets a file stored in the container.
    # @param [Symbol] filename the name of the file.
    # @return [Secret::File] a secret file
    def file(filename)
      fn = filename.to_s
      f  = files[fn]
      return f unless f.nil?
      
      d = ::File.dirname(fn)
      container = d == "." ? self : dir(d)
      
      f  = Secret::File.new(container, ::File.basename(filename) + Secret::FILE_EXT)
      files[fn] = f
      return f
    end
    
    # Another container within the directory
    def dir(name)
      Container.new ::File.join(directory, name), true, chmod_mode
    end

    def method_missing(meth, *args, &block)
      super(meth, *args, &block) if args.any? or block_given?
      return file(meth)
    end


    # Deletes the cache of objects
    def uncache!
      @files = {}
    end

    # This should be called once in some sort of initializer.
    def initialize_once!
      destroy_all_locks!
    end

    # Viciously destroys all locks that the file and its containers may have. Use carefully!
    # @return [Integer] the number of files destroyed.
    def destroy_all_locks!
      files = Dir[::File.join(directory, '*.lock')]
      files.each{|f| ::File.delete(f) }
      return files.count
    end


  end
end