require 'openssl'

class CryptoAES

  def self.aes_encrypt(data)
    cipher = OpenSSL::Cipher::AES.new(128, :CBC)
    cipher.encrypt
    key = cipher.random_key
    iv = cipher.random_iv
    encrypted = cipher.update(data) + cipher.final
    return key+iv, encrypted
  end

  def self.aes_decrypt(key_iv, data)
    decipher = OpenSSL::Cipher::AES.new(128, :CBC)
    decipher.decrypt
    key = key_iv[0..16]
    iv = key_iv[16..32]
    decipher.key = key
    decipher.iv = iv
    plain = decipher.update(data) + decipher.final
  end

end