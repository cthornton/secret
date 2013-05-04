require 'openssl'

module Secret
  module Encryption



    def encrypt_basic(passphrase)
      cipher = OpenSSL::Cipher.new('aes-256-cbc')
      cipher.encrypt
      key = passphrase
      iv  = cipher.random_iv

      out = StringIO.new("", "wb") do |outf|
        StringIO.new(contents, "rb") do |inf|
          while inf.read(4096, buf)
            outf << cipher.update(buf)
          end
          outf << cipher.final
        end
      end

      return out.string
    end

    # Checks to see if the file is encrypted
    def encrypted?
      ::File.exist?(encrypted_meta_filename)
    end


    def stash(content); raise "Not Implemented"; end

    def contents; raise "Not Implemented"; end



    protected

    def encrypted_meta_filename
      raise NotImplementedError, "Must implement dis!"
    end

  end
end