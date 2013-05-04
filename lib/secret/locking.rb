module Secret

  # Locking utilities!
  module Locking

    # By default, wait for locks for 5 seconds
    DEFAULT_LOCK_WAIT_MS = 5000

    # Locks the current file. May prevent other object instances (or processes) from reading / writing to this file.
    # You may use this to upgrade your lock if you wish.
    # @param [Boolean] exclusive if TRUE, holds an exclusive lock meaning that other processes cannot read or write
    #   to the file. If FALSE, allows other files to read from the file, but not to write.
    # @return [Boolean] true if the lock was created successfully, false if it was not (likely due to another process holding a lock,
    #  or we already hold the lock).
    # @note Remember to unlock the file once you are done using it!
    def lock!(exclusive = false)
      return false if(locked? and !owns_lock?)

      # Write
      # The file contents will be of '<exclusive bit>:<process id>'
      lock_string = (exclusive ? '0' : '1') + ":#{Process.pid}"
      ::File.open(lock_file_path, 'w',Secret::CHMOD_MODE) { |f| f.write lock_string }
      @owns_lock = true

      return true
    end

    # Checks to see if this file is locked. Has no indication of whether we own the lock or not.
    # @param [Boolean] exclusive if TRUE, only checks if it's an exclusive lock
    # @return [Boolean] true if the file is locked, false otherwise.
    def locked?(exclusive = false)
      return false unless ::File.exist?(lock_file_path)
      return true unless exclusive # Don't bother checking for non-exlusive
      ex = false
      begin
        # Quickly peek at the file to see if it is exclusive
        ::File.open(lock_file_path, 'r', Secret::CHMOD_MODE) do |f|
          ex = f.seek(1, IO::SEEK_CUR) == '1'
          f.close
        end
        return ex
      rescue Exception => e
        return false
      end
    end


    # An alias for {#owns_lock}
    def owns_lock?
      return owns_lock
    end

    # Unlocks this file.
    # @return [Boolean] true if unlock was successful, false if unlock was unsuccessful (i.e. the file wasn't locked,
    #   or we don't own the lock)
    def unlock!
      return false if !locked?
      return false if !owns_lock?

      ::File.delete(lock_file_path)
      @owns_lock = false
      return true
    end

    # Forcibly unlocks this file, regardless of whether the lock is owned
    # @return [Boolean] true if unlock was successful, false if the file isn't locked.
    def force_unlock!
      return false if !locked?
      ::File.delete(lock_file_path)
      @owns_lock = false
      return true
    end


    # Waits for the file to become unlocked for 'max_time_ms'. If file is locked for that long, then raises an
    # {Secret::::FileLockedError}.
    # @param [Boolean] exclusive if TRUE, waits for an exclusive lock or shared lock, and then locks with an
    #   exclusive lock if a block is given. If FALSE, then only waits for an exclusive lock.
    # @param [Integer] max_time_ms the maximum number of MS to wait until raising an error. If negative, waits forever.
    # @param [Integer] sleep_ms the number of MS to sleep before polling the lock again
    # @param [Proc] block pass a block to then execute block while locked (i.e. {#lock_and_do})
    def wait_for_unlock(exclusive = false, max_time_ms = DEFAULT_LOCK_WAIT_MS, sleep_ms = 100, &block)
      ms_start = (Time.now.to_f * 1000.0).to_i
      wait_exclusive = exclusive or block_given?
      sleep_ms = sleep_ms / 1000.0
      while locked?(!wait_exclusive)
        break if owns_lock?
        sleep(sleep_ms)
        continue if max_time_ms < 0
        ms_new = (Time.now.to_f * 1000.0).to_i
        if (ms_new - ms_start) > max_time_ms
          raise Secret::FileLockedError, "Timeout of #{max_time_ms} MS exceeded while waiting for lock!"
        end
      end

      # If we are here, waiting has finished
      lock_and_do(exclusive, &block) if block_given?
    end

    # Locks and executes a block, then unlocks upon block execution. This will always ensure that the lock
    # is released upon block execution, regardless of error or no.
    # @param [Boolean] exclusive if TRUE, uses an exclusive lock. If false, uses a shared lock
    # @raise [ArgumentError] if a block is not provided
    # @raise [FileLockedError] if the file is locked
    def lock_and_do(exclusive = false, &block)
      raise ArgumentError, 'Block not given' unless block_given?
      raise Secret::FileLockedError, 'Cannot lock a file if it is already locked!' if locked?
      lock!(exclusive)
      begin
        block.call
      rescue Exception => e
        raise e
      ensure
        unlock!
      end
    end


    # Gets information about the current lock:
    #
    #   {:pid => 123123, :exclusive => true }
    #
    # @return [Hash,nil] information about the current lock, or nil if no lock is present
    def lock_info
      return nil unless locked?
      begin
        str = nil
        ::File.open(lock_file_path, 'r', Secret::CHMOD_MODE) {|f| str = f.read }
        ex,pid = str.split ':'
        return {:exclusive => (ex == "1"), :pid => pid.to_i}
      rescue Exception => e
        return nil
      end
    end

    protected

    def lock_file_path
      raise NotImplementedError, "'lock_file_path' needs to be implemented"
    end
  end
end