class UserDeviceArxanKeysGen

   def initialize()
     @key_gen = ArxanKeygenRSA.new
   end

   #openSSL keys and Arxan key pairs gen for new account creation
   def gen_arxan_key_pairs
    if !@key_gen.arxan_key_pairs_gen
      return false
    end
    @key_gen.load_all_key_pairs
  end

  def get_openssl_priv_key_data
    @key_gen.keys_loaded?
    return @key_gen.get_openssl_priv_key_data
  end

  def get_user_device_arxan_key_pairs_base64
    @key_gen.keys_loaded?
    arxan_private_key = @key_gen.get_arxan_priv_key_data_base64
    arxan_public_key = @key_gen.get_arxan_pub_key_data_base64
    return arxan_private_key, arxan_public_key
  end

end