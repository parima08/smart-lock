require 'openssl'
require 'fileutils'

class BaseKeygen

 def initialize(dir=nil)
    @rsa_key_size = GojiCryptoParam::RSA_KEY_SIZE.to_i
    @openssl_priv_key_name ='private_key'
    @openssl_pub_key_name ='public_key'
    @openssl_key_format = '.pem'
    @openssl_priv_tmp_file = nil
    @openssl_pub_tmp_file = nil
    @arxan_pub_tmp_file = nil
    @arxan_priv_tmp_file = nil

    @openssl_cmd= 'openssl genrsa -out '
    @arxan_pub_key_data = nil
    @arxan_priv_key_data = nil
    @openssl_priv_key = nil
    @openssl_pub_key = nil
    @keys_created = false
    @keys_loaded = false

    if @rsa_key_size==1024
      @arxan_cmd ='./app/arxanUtil/bin/TFIT_keygen_iRSA1024 '
      @arxan_pub_key_name ='TFIT_rsa_pub_iRSA1024'
      @arxan_priv_key_name ='TFIT_rsa_priv_iRSA1024'
    else
      @arxan_cmd ='./app/arxanUtil/bin/TFIT_keygen_iRSA2048 '
      @arxan_pub_key_name ='TFIT_rsa_pub_iRSA2048'
      @arxan_priv_key_name ='TFIT_rsa_priv_iRSA2048'
    end
  end

end