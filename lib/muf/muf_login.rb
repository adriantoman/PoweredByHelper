module PowerByHelper

  class MufLogin

    attr_accessor :login,:mufs,:user_muf_url


    def initialize(login,user_profile_url,user_muf_url)
      super()
      @login = login
      @user_profile_url = user_profile_url
      @user_muf_url = user_muf_url
      #@muf_url = muf_url
      @mufs = []
    end


    def add_muf(muf)
      @mufs.push(muf)
    end

    def find_muf_by_attribute(attribute_id,type)
      @mufs.find{|muf| muf.attribute == attribute_id and (muf.type = type or (muf.type.nil? and type == :in))}
    end

    def get_gooddata_representation(pid)
      gooddata_compatible = []
      @mufs.each do |muf|
        gooddata_compatible.push(muf.create_gooddata_muf_representation(pid))
      end
      gooddata_compatible.join(" AND ")
    end

    def reset_muf
      @mufs.each do |muf|
        muf.values = muf.new_values
        muf.new_values = {}
      end
    end

    state_machine :state, :initial => :start do
      state :start
      state :create
      state :ok
      state :to_delete
      state :changed


      event :to_delete do
        transition :start => :to_delete,[:ok,:create] => :changed
      end

      event :same do
        transition :start => :ok,[:to_delete,:create] => :changed
      end

      event :new do
        transition :start => :create,[:ok,:to_delete] => :changed
      end

      event :change do
        transition [:start,:ok,:create] => :changed
      end

      event :clear do
        transition all => :start
      end



    end




  end

end