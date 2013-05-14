require "secret/version"
require "secret/encryption"
require "secret/file"
require "secret/container"

module Secret

  # The chmod mode to use for files.
  CHMOD_MODE = 0700
  
  # The file extension for secret files
  FILE_EXT = ".sf"
  
  # Gets the default container
  # @return [Secret::Container] the default container
  def self.default
    raise ArgumentError, "Must call 'Secret.configure_default' before you can access the default container" unless @default
    return @default
  end

  # Configures the default container once
  def self.configure_default(directory, auto_create = true)
    unless @default
      @default = Secret::Container.new(directory, auto_create)
      @default.initialize_once!
      return true
    else
      return false
    end
  end

  class FileUnreadableError < Exception; end
  
  class FileEncryptedError < Exception; end


end
