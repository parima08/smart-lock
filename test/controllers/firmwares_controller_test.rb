require "test_helper"
require 'open-uri'
require 'net/ftp'

class FirmwaresControllerTest < ActionController::TestCase

  describe FirmwaresController do

    subject { FirmwaresController }

    before do
      DatabaseCleaner.start
      @routes = Rails.application.routes
      @admin_user, @device, @user_device = make_user_core('glenn@example.com', 'aba456', true, nil)
      # XXX simpler pattern, use everywhere (pictures)?
      @file_path = "#{::Rails.root.to_s}/test/data/firmware_image.bin"
      @mime_type = "application/binary"
      @ref_file_data = write_test_file()
      @upload_file = Rack::Test::UploadedFile.new(@file_path, @mime_type)
    end

    after do
      DatabaseCleaner.clean
    end

    it "must respond" do
      assert @routes
      #no actual request above...
    end

    it "should require you to be a sysadmin to upload firmware" do
      @normal_user, @device2, @user_device2 = make_user('normaluser@example.com', 'aba456')
      send_auth(@user_device2)
      post(:create,
           :for_external => true,
           :version => "vstr",
           :file  => @upload_file)
      check_response 401
    end

    it "should return invalid data error on no version parameters" do
      send_auth(@user_device)
      post(:create,
           :for_external => true,
           :file  => @upload_file)
      check_response 422
    end

    it "should return invalid data error on no for_external parameter" do
      send_auth(@user_device)
      post(:create,
           :version  => "vstr",
           :file  => @upload_file)
      check_response 422
    end
    it "should return invalid data error on no file parameter" do
      send_auth(@user_device)
      post(:create,
           :version  => "vstr",
           :for_external => true)
      check_response 422
    end

    it "should return 422 invalid error when string excceeds 255 characters" do
      invalid_description = "thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_thisisten_"
      send_auth(@user_device)
      post(:create,
          description: invalid_description,
          version: "test_version",
          for_external: "true",
          file: @upload_file,
      )
      check_response 422
    end

    def write_test_file()
      ref_file_data = "this is a dummy firmware image" + DateTime.now.utc.iso8601(6).to_s
      ref_file = File.new(@file_path, "w+")
      ref_file.write(ref_file_data)
      ref_file.close
      ref_file_data
    end

    # Download and check the file from S3
    def check_published(ref_data)
      # I suspect that S3 isn't syncronous when reposting the file
      # (which currently isn't actually possible unless you erase the
      # server DB or use another server.)  Causes intermittent
      # old-file returns.  Not sure if this means that the file might
      # not even be there right away the first time...
      sleep 30
      s3_file = open(Firmware::HTTP_ROOT + ref_data[:download_url]).read
      assert_equal @ref_file_data, s3_file, 'file downloaded from s3 has correct contents'
      # Download and check the file from the proxy ftp server
      ftp = Net::FTP.new
      ftp.connect(Firmware::FTP_HOST, 21)
      ftp.login(Firmware::FTP_USER, Firmware::FTP_PASS)
      ftp.passive = true
      local_filename = "test_version"
      ftp.getbinaryfile(ref_data[:download_url], local_filename)
      file = open(local_filename)
      ftp_file = file.read
      file.close
      assert_equal @ref_file_data, ftp_file, 'file downloaded from ftp server has correct contents'
      File.delete(local_filename)
      File.delete(@file_path)
    end

    it "should create without description" do
      ref_data = {
        version: "test_version",
        for_external: "true",
        file: @upload_file,
        authtoken: @user_device.authentication_token,
        user_device_id: @user_device.id,
      }
      assert_difference('Firmware.count', 1) do
        send_auth(@user_device)
        post(:create, ref_data)
        check_response
      end
      ref_data[:download_url] = 'external/v2/test_version'
      check_data(Firmware.first, ref_data, nil, false, [:file, :authtoken, :user_device_id ])
      check_published(ref_data)
    end

    it "should create with description" do
      ref_data = {
        version: "test_version",
        description: "a description",
        for_external: "false",
        file: @upload_file
      }
      assert_difference('Firmware.count', 1) do
        send_auth(@user_device)
        post(:create, ref_data)
        check_response
      end
      ref_data[:download_url] = 'internal/v2/test_version'
      check_data(Firmware.first, ref_data, nil, false, [:file])
      # Uncomment when we can shrink the sleep above.
      #check_published(ref_data)
    end

    it "should create and not update created_at and updated_at" do
      ref_data = {
        version: "test_version",
        for_external: "true",
        file: @upload_file,
        user_device_id: @user_device.id,
        created_at: "2014-09-23T23:56:18.786Z",
        updated_at: "2014-09-23T23:59:39.802Z"
      }
      assert_difference('Firmware.count', 1) do
        send_auth(@user_device)
        post(:create, ref_data)
        check_response
      end
      ref_data[:download_url] = 'external/v2/test_version'
      check_data(Firmware.first, ref_data, [:created_at, :updated_at], false, [:file, :user_device_id ])
      check_published(ref_data)
      assert_not_equal Firmware.first.created_at, ref_data[:created_at]
      assert_not_equal Firmware.first.updated_at, ref_data[:updated_at]
    end
  end
end
