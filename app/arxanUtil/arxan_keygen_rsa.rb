require 'base_keygen.rb'

class ArxanKeygenRSA < BaseKeygen

   def initialize(dir='/tmp')
    super(dir)
    if !dir.nil?
      #Arxan bin cannot write files to /tmp in Heroku server,
      #only works with subdir with changing mode.
      @out_dir = dir +'/room5'
      if !Dir.exist?(@out_dir)
        Dir.mkdir(@out_dir)
        FileUtils.chmod 0755, @out_dir
      end
      @keys_dir = dir
    else
      @keys_dir = 'app/arxanUtil/keys/'
    end
   end

  def arxan_key_pairs_gen
    if @rsa_key_size==1024
      rsa_key = OpenSSL::PKey::RSA.new 1024
    elsif @rsa_key_size==2048
      rsa_key = OpenSSL::PKey::RSA.new 2048
    else
      puts 'ERROR RSA key size'
      return false
    end
    file_type= [@openssl_priv_key_name, @openssl_key_format]
    private_key = rsa_key.to_pem
    file =  Tempfile.new(file_type)
    @openssl_priv_tmp_file = file
    if !file.nil?
      begin
        file.write(private_key)
      ensure
        file.close
      end
    else
        retrun false
    end
    public_key = rsa_key.public_key.to_pem
    file_type= [@openssl_pub_key_name, @openssl_key_format]
    file = Tempfile.new(file_type)
    @openssl_pub_tmp_file = file
    if !file.nil?
      begin
        file.write(public_key)
      ensure
        file.close
      end
    else
        retrun false
    end
    cmd = String.new(@arxan_cmd)
    cmd.concat('--key_pem ')
    cmd.concat(@openssl_priv_tmp_file.path)
    timestamp = Time.now.to_i.to_s
    cmd.concat(' --suffix=_')
    cmd.concat(timestamp)
    cmd.concat(' --outdir=')
    cmd.concat(@out_dir)
    ret = system(cmd)
    if  ret== false || ret == nil
      puts 'Can not execute command: ' + cmd
      return false
   end
   @arxan_pub_tmp_file = @out_dir + '/'+ @arxan_pub_key_name + '_' + timestamp + '.dat'
   @arxan_priv_tmp_file= @out_dir + '/'+ @arxan_priv_key_name + '_' + timestamp + '.dat'
   @keys_created = true
  end

  def keys_loaded?
    if !@keys_created
      arxan_key_pairs_gen
    end
    if !@keys_loaded
      load_all_key_pairs
    end
  end

  def load_all_key_pairs
    @arxan_pub_key_data = read_file(@arxan_pub_tmp_file, 'arxan')
    @arxan_priv_key_data = read_file(@arxan_priv_tmp_file, 'arxan')
    @openssl_pub_key = read_file(@openssl_pub_tmp_file, 'openssl')
    @openssl_priv_key = read_file(@openssl_priv_tmp_file, 'openssl')
    @keys_loaded = true
  end

  def get_arxan_pub_key_data_base64
    Base64.strict_encode64(@arxan_pub_key_data)
  end

  def get_arxan_priv_key_data_base64
    Base64.strict_encode64(@arxan_priv_key_data)
  end

  def get_openssl_pub_key_data
    @openssl_pub_key.to_pem
  end

  def get_openssl_priv_key_obj
    @openssl_priv_key
  end

  def get_openssl_priv_key_data
    @openssl_priv_key.to_pem
  end

 private
  def read_file(file_name, type)
    data = nil
    if type =='openssl'
      file = file_name.open
      return false if !file
      begin
      data = OpenSSL::PKey::RSA.new file.read()
      ensure
      file.close
      file_name.unlink
      end
    elsif type == 'arxan'
      if File.exist?(file_name)
        file =File.open(file_name)
        return false if !file
        begin
        data = file.read()
        ensure
        file.close
        File.unlink(file_name)
        end
      end
    end
    return data
  end

end