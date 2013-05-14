require 'aes'

module Secret
  
  # Enables basic encryption support with AES.
  #
  # Note that encryption and decription are rather slow processes and are intended to be
  # used with small strings / file sizes. Please use sparingly!
  module Encryption



    # Gets the contents of the file in an encrypted format. This may quite possibly
    # result in doubly-encrypted text if you're not careful. This process will take
    # a few moments.
    def encrypted(passphrase)
      return contents if encrypted?
      encrypt_string passphrase, contents
    end

    
    # Gets the decrypted version of this.
    # @raise [OpenSSL::Cipher::CipherError] if the password was incorrect
    def decrypted(passphrase)
      return contents unless encrypted?
      AES.decrypt contents, passphrase
    end
    
    # Immediately decrypt the contents of this file.
    # @raise [OpenSSL::Cipher::CipherError] if the password was incorrect
    def decrypt!(passphrase)
      raise ArgumentError, "The contents of this file are not encrypted" unless encrypted?
      str = decrypted(passphrase)
      remove_encrypted_indicator
      stash str
    end

    # Encrypt the contents of this file immediately
    def encrypt!(passphrase)
      stash_encrypted passphrase, contents
    end
    
    # Change the passphrase.
    def change_encryption_passphrase!(old_passphrase, new_passphrase)
      raise ArgumentError, "The contents of this file are not encrypted" unless encrypted?
      original = decrypted old_passphrase
      remove_encrypted_indicator
      stash_encrypted original, new_passphrase
    end
    
    # Stash the contents of this file with an encrypted password
    def stash_encrypted(data, passphrase)
      raise ArgumentError, "The contents of this file is already encrypted" if encrypted?
      ::File.open(encrypted_meta_filename, 'w', container.chmod_mode) {|f| f.write "aes-default" }
      str = encrypt_string passphrase, data
      stash str
      ::File.open(encrypted_meta_filename, 'w', container.chmod_mode) {|f| f.write "aes-default" }
    end


    # Checks to see if the file is encrypted
    def encrypted?
      ::File.exist?(encrypted_meta_filename)
    end

    # Ensure that the contents of this file are unencrypted
    def ensure_unencrypted!
      raise FileEncryptedError, "Contents of the file are encrypted" if encrypted?
    end


    def remove_encrypted_indicator
      ::File.delete encrypted_meta_filename if encrypted?
    end

    protected
    
    def encrypt_string(passphrase, string)
      iv = AES.iv :base_64
      return AES.encrypt string, passphrase, :iv => iv
    end

    def encrypted_meta_filename
      file_path + '.enc'
    end
  
    

  end
end