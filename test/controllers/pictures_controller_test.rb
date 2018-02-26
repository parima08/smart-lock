require "test_helper"

class PicturesControllerTest < ActionController::TestCase

  describe PicturesController do

    subject { PicturesController}
    
    describe "create/POST" do

      before do
        DatabaseCleaner.start
        @routes = Rails.application.routes
        @user, @device, @user_device   = make_user
        @lock   = make_lock(@user)
      end

      after do
        DatabaseCleaner.clean
      end

      it "must respond" do
        assert @routes
      end

      it "should save an image by lock_id" do
        prep_post_data
        post(:create, @post_data)
        check_response
        check_picture_data
        check_s3_file
      end

      it "should save an image by lock_serial" do
        prep_post_data
        @post_data.delete(:lock_id)
        post(:create, @post_data.merge({ lock_serial: @lock.lock_serial }))
        check_response
        check_picture_data
        check_s3_file
      end

      it "should require valid lock_id/lock_serial" do
        prep_post_data
        post(:create, @post_data.merge({ lock_id: nil }))
        # MISSING_PARAM would be OK here too.
        check_response(404, :MISSING_RECORD)
      end

      it "should require lock_id/lock_serial" do
        prep_post_data
        @post_data.delete(:lock_id)
        post(:create, @post_data)
        check_response(422, :MISSING_ALL_PARAMS)
      end

      it "should require taken_at" do
        prep_post_data
        @post_data.delete(:taken_at)
        post(:create, @post_data)
        check_response(422, :MISSING_PARAM)
      end

      it "should require picture" do
        prep_post_data
        @post_data.delete(:picture)
        post(:create, @post_data)
        check_response(422, :MISSING_PARAM)
      end
      it "should fail if picture params not unique" do
        prep_post_data
        post(:create, @post_data)
        check_response
        check_picture_data
        check_s3_file
        post(:create, @post_data)
        check_response(422, :INVALID_PARAM)
      end

      it "should update the lock wifi status" do
        @lock.reported_wifi_status = LockCommState::LOCK_COMM_DOWN
        @lock.save
        prep_post_data
        post(:create, @post_data)
        check_response
        @lock.reload
        assert_equal @lock.reported_wifi_status, LockCommState::LOCK_COMM_UP
        fuzzy_compare_datetime(DateTime.now, @lock.updated_at, 2)
      end

      def prep_post_data
        File.open("#{Rails.root}/test/data/test.jpeg", 'r') do |f|
          @raw_file = f.read
          @encoded_file = Base64.encode64(@raw_file)
        end
        @post_data = {
          lock_id: @lock.id,
          taken_at: comparable_payload_date_now,
          picture: {data: @encoded_file, content_type: 'image/jpeg', original_filename: 'test.jpeg'}
        }
      end

      def check_s3_file
        s3_file_url   = Picture.first.data.expiring_url
        s3_file       = HTTParty.get(s3_file_url).body
        @raw_file.bytes.each_with_index do |char, i|
          if s3_file.bytes[i] != char
            print "wrong char at " + i.to_s + ": #{char}  #{s3_file.bytes[i]}\n"
            print "s3_file=" + s3_file
          end
          assert_equal s3_file.bytes[i], char
        end
      end

      def check_picture_data
        check_data(Picture.last, @post_data, [:picture], true)
      end

    end
  end
end
