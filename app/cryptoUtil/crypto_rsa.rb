require 'openssl'

class CryptoRSA

  #require pass openSSL private key pem format file
  def initialize(private_key_pem=nil)
    if private_key_pem
      @priv_key_obj = OpenSSL::PKey::RSA.new(private_key_pem)
    else
      #default for goji master key object
      priv_key_path=String.new('app/arxanUtil/keys/GojiMasterKeys/private_key.pem')
      @priv_key_obj = OpenSSL::PKey::RSA.new File.read(priv_key_path)
    end
  end

  def get_public_key_pem
    return nil if @priv_key_obj.nil?
    privKey = @priv_key_obj
    return nil if !privKey.private?
    pubKey = privKey.public_key
    return nil if !pubKey.public?
    pubKey.to_pem
  end

  def rsa_sign_sha256(data)
    dgst = OpenSSL::Digest::SHA256.new
    privKey = @priv_key_obj
    return false if !privKey.private?
    privKey.sign(dgst, data)
  end

  def rsa_verify_sha256(signature, data)
    dgst = OpenSSL::Digest::SHA256.new
    privKey = @priv_key_obj
    if !privKey.private?
      return
    end
    pubKey = privKey.public_key
    return false if !pubKey.public?
    return true if pubKey.verify(dgst, signature, data)
    return false
  end

  def rsa_sign_sha1(data)
    dgst = OpenSSL::Digest.new(GojiCryptoParam::RSA_SIGN_DIGEST)
    privKey = @priv_key_obj
    return false if !privKey.private?
    privKey.sign(dgst, data)
  end

  def rsa_verify_sha1(signature, data)
    dgst = OpenSSL::Digest.new(GojiCryptoParam::RSA_SIGN_DIGEST)
    privKey = @priv_key_obj
    if !privKey.private?
      return
    end
    pubKey = privKey.public_key
    return false if !pubKey.public?
    return true if pubKey.verify(dgst, signature, data)
    return false
  end

   def rsa_priv_encrypt(data)
    privKey = @priv_key_obj
    return if !privKey.private?
    return privKey.private_encrypt(data, OpenSSL::PKey::RSA::PKCS1_PADDING)
  end

  def rsa_pub_decrypt(data)
    privKey = @priv_key_obj
    pub_key = privKey.public_key
    return if !pub_key.public?
    privKey.public_decrypt(data, OpenSSL::PKey::RSA::PKCS1_PADDING)
  end

end
