require 'test_helper'
class TimeConstraintTest < MiniTest::Unit::TestCase

  describe TimeConstraint do

    before do
      DatabaseCleaner.start
      @user, device, user_device  = make_user
      @lock    = make_lock(@user)
      @key     = make_key(@lock, @user)
      @tc      = TimeConstraint.create(:key_id => @key.id)
    end

    after do
      DatabaseCleaner.clean
    end

    subject { @tc }

    # shoulda matcher syntax


=begin
    # No longer needed
    it "should respond to a save_key callback method" do
      assert @tc.respond_to?(:save_key)
    end
=end

    it "should save key after it is saved" do
      assert_false @key.is_fob, "is_fob false"
      @tc.key.is_fob = true
      @tc.save!
      assert_true @tc.key.is_fob, "is_fob updated to true"
    end

   it "should have a working days of week bitmask method" do
      @tc.sunday = 1
      assert @tc.save
      bit_value = TimeConstraint.get_days_bitmask(@tc)
      assert_equal bit_value.to_s(2), "1000000"
      @tc.wednesday = 1
      assert @tc.save
      bit_value = TimeConstraint.get_days_bitmask(@tc)
      assert_equal bit_value.to_s(2), "1001000"
   end

   it "should accept a start_offset and end_offset" do
     @tc.start_offset = "-150"
     @tc.end_offset   = "360"
     assert @tc.save
     assert_equal = -150, @tc.start_offset
     assert_equal = 360, @tc.end_offset
   end

   # Testing start_offset and end_offset validations
   it "should not allow a end_offset before a start offset" do
     @tc.start_offset = "200"
     @tc.end_offset = "100"
     assert !@tc.valid?, "should not be valid"
     assert @tc.errors.include?(:end_offset), "should error on end_offset"
   end

   it "should not allow invalid start or end offsets" do
     @tc.start_offset = "abc"
     @tc.end_offset = "10.2"
     assert !@tc.valid?, "should not be valid"
     assert @tc.errors.include?(:start_offset), "should error on start_offset"
     assert @tc.errors.include?(:end_offset), "should error on end_offset"
   end

  end

end
