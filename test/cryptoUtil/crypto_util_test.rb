require 'test_helper'
require 'arxan_keygen_rsa'
require 'crypto_rsa'

class CryptoUtilTest <  MiniTest::Unit::TestCase
  describe CryptoUtilTest do
    subject { CryptoUtilTest }

    it "generate openSSL RSA keys and Arxan whitebox key pairs" do
      tool = ArxanKeygenRSA.new
      tool.arxan_key_pairs_gen
      #after load keys, remove all keys from /tmp
      tool.load_all_key_pairs
    end

    it "sign with plain text and verify" do 
      data='Hello world'
      signature = Base64.strict_decode64(GojiMasterKeysGen.sign(data))
      rsa = CryptoRSA.new(GojiMasterKeysGen.get_goji_master_private_key)
      verified = rsa.rsa_verify_sha1(signature, data)
      assert verified==true
    end

    it "sign with RSA encrypted text, verify sinature and decrypt to plain text" do
      goji_master_key = GojiMasterKeysGen.get_goji_master_private_key
      rsa = CryptoRSA.new(goji_master_key)
      data='Hello world'
      enc = rsa.rsa_priv_encrypt(data)
      signature = rsa.rsa_sign_sha1(enc)
      verified=rsa.rsa_verify_sha1(signature, enc)
      assert verified==true
      plain = rsa.rsa_pub_decrypt(enc)
      puts plain
      assert(data, plain)
    end

     it "sign with AES cbc-128 encrypted text, verify sinature and decrypt to plain text" do
      goji_master_key = GojiMasterKeysGen.get_goji_master_private_key
      rsa = CryptoRSA.new(goji_master_key)
      data='Hello world'
      key_iv, enc = CryptoAES.aes_encrypt(data)
      signature = rsa.rsa_sign_sha1(enc)
      key_enc = rsa.rsa_priv_encrypt(key_iv)
      verified = rsa.rsa_verify_sha1(signature, enc)
      assert verified==true
      key_iv = rsa.rsa_pub_decrypt(key_enc)
      decrypted = CryptoAES.aes_decrypt(key_iv, enc)
      assert(data, decrypted)
    end
  end
end