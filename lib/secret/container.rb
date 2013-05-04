module Secret
  class Container

    attr_reader :directory, :files

    # Initializes a container. Does significant checking on the directory to ensure it is writeable and it exists.
    # @param [String] directory the directory to the container
    # @param [Boolean] auto_create if true, will attempt to create the directory if it does not exist.
    def initialize(directory, auto_create = true)
      @directory = directory

      @files = {}

      # Do some checking about our directory
      if ::File.exist?(directory)
        raise ArgumentError, "Specified directory '#{directory}' is actually a file!" unless ::File.directory?(directory)

      # Now make our directory if auto_create
      else
        raise ArgumentError, "Specified directory '#{directory}' does not exist!" unless auto_create
        Dir.mkdir(directory, Secret::CHMOD_MODE) # Only give read/write access to this user
      end
      raise ArgumentError, "Directory '#{directory}' is not writeable!" unless ::File.writable?(directory)
    end

    # Gets a file stored in the container.
    # @param [Symbol] filename the name of the file.
    # @return [Secret::File] a secret file
    def file(filename)
      fn = filename.to_sym
      f  = files[fn]
      return f unless f.nil?
      f  = Secret::File.new(self, filename)
      files[fn] = f
      return f
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