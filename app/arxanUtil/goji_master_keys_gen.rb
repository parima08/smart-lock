require 'base_keygen.rb'

class GojiMasterKeysGen < BaseKeygen
   @@goji_master_private_key = nil

   def initialize(dir='GojiMasterKeys')
    super(dir)
    @openssl_priv_key_name = @openssl_priv_key_name +  @openssl_key_format
    @openssl_pub_key_name =@openssl_pub_key_name +  @openssl_key_format
    @keys_dir = 'app/arxanUtil/keys/'
    @goji_dir = dir

    if @rsa_key_size==1024
      @arxan_pub_key_name  = @arxan_pub_key_name  + '.dat'
      @arxan_priv_key_name = @arxan_priv_key_name + '.dat'
    else
      @arxan_pub_key_name  = @arxan_pub_key_name  + '.dat'
      @arxan_priv_key_name = @arxan_priv_key_name + '.dat'
    end
   end
  #return openSSL private key pem format
  def self.get_goji_master_private_key
    if @@goji_master_private_key
      return @@goji_master_private_key
    end
    #Encrypted private_key pem file, decrypt to private pem key
    #Heroku ENV does not like newline characters, use strict_encode64/decode64
    privKey_base64 = ENV['GOJI_MASTER_PRIVATE_KEY']
    privKey_aes = Base64.strict_decode64(privKey_base64)
    passphrase = ENV['GOJI_MASTER_PASSPHRASE']
    @@goji_master_private_key = decrypt_goji_master_private_key(privKey_aes, passphrase)
  end

  def self.decrypt_goji_master_private_key(encrypted_key, passphrase)
    rsa_key_obj = OpenSSL::PKey::RSA.new(encrypted_key, passphrase)
    rsa_key_obj.to_pem
  end

  def self.sign(data)
    rsa = CryptoRSA.new(get_goji_master_private_key)
    Base64.strict_encode64(rsa.rsa_sign_sha1(data))
  end

  def goji_master_keys_gen
    key_dir=@goji_dir
    arxan_key_pairs_gen(key_dir)
  end

  def get_arxan_pub_key_data
    @arxan_pub_key_data
  end

  def get_arxan_priv_key_data
    @arxan_priv_key_data
  end

  def get_openssl_pub_key_data
    @openssl_pub_key.to_pem
  end

  def get_openssl_priv_key_obj
    @openssl_priv_key
  end

  def get_openssl_priv_key_data(sub_dir=nil)
    key_dir = String.new(@keys_dir)
    if !sub_dir.nil?
      key_dir.concat(sub_dir)
      key_dir.concat('/')
    end
    file_name = String.new(key_dir)
    file_name.concat(@openssl_priv_key_name)
    @openssl_priv_key = read_file(file_name, 'openssl')
    if @openssl_priv_key
      return @openssl_priv_key.to_pem
    end
  end

  def load_all_key_pairs(sub_dir=nil)
    key_dir = String.new(@keys_dir)
    if !sub_dir.nil?
      key_dir.concat(sub_dir)
      key_dir.concat('/')
    end
    file_name = String.new(key_dir)
    file_name.concat(@arxan_pub_key_name)
    @arxan_pub_key_data = read_file(file_name, 'arxan')
    file_name = String.new(key_dir)
    file_name.concat(@arxan_priv_key_name)
    @arxan_priv_key_data = read_file(file_name, 'arxan')
    file_name = String.new(key_dir)
    file_name.concat(@openssl_pub_key_name)
    @openssl_pub_key = read_file(file_name, 'openssl')
    file_name = String.new(key_dir)
    file_name.concat(@openssl_priv_key_name)
    @openssl_priv_key = read_file(file_name, 'openssl')
    return true
  end

  def arxan_key_pairs_gen(sub_dir=nil)
    if @rsa_key_size==1024
      rsa_key = OpenSSL::PKey::RSA.new 1024
    elsif @rsa_key_size==2048
      rsa_key = OpenSSL::PKey::RSA.new 2048
    else
      puts 'ERROR RSA key size'
      return
    end
    key_dir = String.new(@keys_dir)
    if !sub_dir.nil?
      key_dir.concat(sub_dir)
      key_dir.concat('/')
    end
    if !Dir.exist?(key_dir)
      FileUtils.mkdir_p key_dir
    end
    path= String.new(key_dir)

    path.concat(@openssl_priv_key_name)
    private_key = rsa_key.to_pem
    file = File.open(path, 'wb')
    if !file.nil?
      begin
      file.write(private_key)
      ensure
      file.close
      end
    end
    public_key = rsa_key.public_key.to_pem
    path=String.new(key_dir)
    path.concat(@openssl_pub_key_name)
    file = File.open(path, 'wb')
    if !file.nil?
      begin
      file.write(public_key)
      ensure
      file.close
      end
    end
    cmd = String.new(@arxan_cmd)
    cmd.concat('--key_pem ')
    cmd.concat(key_dir)
    cmd.concat(@openssl_priv_key_name)
    cmd.concat(' --outdir=')
    cmd.concat(key_dir)
    ret = system(cmd)
    if  ret== false || ret == nil
      puts 'Can not execute command: ' + cmd
      return false
   end
   return true
  end

  private
  def read_file(file_name, type)
    if File.exist?(file_name)
      file =File.open(file_name)
      if type == 'arxan'
        begin
        data = file.read()
        ensure
        file.close
        end
      elsif type == 'openssl'
        begin
        data = OpenSSL::PKey::RSA.new file.read()
        ensure
        file.close
        end
      end
      return data
    end
    return false
  end
end