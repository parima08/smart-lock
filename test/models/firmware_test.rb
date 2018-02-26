require "test_helper"

class FirmwareTest < ActiveSupport::TestCase
  # Most other stuff here should be covered by firmwares_controller_test.rb

  it "should enforce uniqueness of version, for_external pair" do
    @firmware = Firmware.new(
      "version"=>"0.0.9T",
      "description"=>"testOTA",
      "for_external"=>true,
      "download_url"=>"external/v2/0.0.9T",
      "data_file_name"=>"0.0_1_.9T",
      "data_content_type"=>"application/octet-stream",
      "data_file_size"=>125315,
      "data_updated_at"=>"2014-09-23T23:59:39.799Z")

    @firmware2 = @firmware.dup
    assert @firmware.save
    assert !@firmware2.save # Saving a duplicate should fail
    assert @firmware.errors
  end

  it "should nilify description field" do
    @firmware = Firmware.new()
    @firmware.description = ""
    @firmware.valid? # This will fail at the moment
    assert_equal nil, @firmware.description
  end

end
