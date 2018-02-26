module DataNormalizer
  extend ActiveSupport::Concern


  private
  
  def nilify_zeros(*args)
    args.each do |field|
      if self[field] == 0
        self[field] = nil
      end
    end
  end

  # See lock.rb
  def clone_user_id
    self.user_account_id = user_id
  end

end
