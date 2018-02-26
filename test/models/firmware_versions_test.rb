require "test_helper"

class FirmwareVersionsTest < ActiveSupport::TestCase
  describe FirmwareVersions do 
    before do
      DatabaseCleaner.start
      @fv = FirmwareVersions.new
      @fv.save
    end

    after do
      DatabaseCleaner.clean
    end

    def set_field(field, value)
      @fv.update_attribute(field, value)
      @fv.save!
    end

    it "should reject invalid default_required_internal_version" do
      assert_raises ActiveRecord::RecordInvalid do
        set_field(:default_required_internal_version, "invalid")
      end
    end

    it "should reject default_invalid required_external_version" do
      assert_raises ActiveRecord::RecordInvalid do
        set_field(:default_required_external_version, "invalid")
      end
    end

    it "should accept valid default_required_internal_version" do
      make_dummy_firmware_versions()
      set_field(:default_required_internal_version, ActiveSupport::TestCase.INTERNAL_VERSION)
    end
   
    it "should accept valid default_required_external_version" do
      make_dummy_firmware_versions()
      set_field(:default_required_external_version, ActiveSupport::TestCase.EXTERNAL_VERSION)
    end
  end
end
