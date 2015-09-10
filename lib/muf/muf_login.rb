module PowerByHelper

  class MufLogin

    attr_accessor :login,:mufs


    def initialize(login,user_profile_url)
      super()
      @login = login
      @user_profile_url = user_profile_url
      @mufs = []
    end


    def add_muf(muf)
      @mufs.push(muf)
    end

    def find_muf_by_attribute(attribute_id,type)
      @mufs.find{|muf| muf.attribute == attribute_id and (muf.type = type or (muf.type.nil? and type == :in))}
    end

    # def get_gooddata_representation(pid)
    #   output = []
    #   grouped_mufs = @mufs.group_by{|m| m.type }
    #   grouped_mufs.each_pair do |type,mufs_grouped_collection|
    #     if (type == :in)
    #       gooddata_compatible = []
    #       mufs_grouped_collection.each do |muf|
    #         gooddata_compatible.push(muf.create_gooddata_muf_representation(pid))
    #       end
    #       output << {
    #           :uri => mufs_grouped_collection.first.muf_url,
    #           :expression => gooddata_compatible.join(" AND ")
    #       }
    #     elsif (type == :over)
    #       mufs_grouped_collection.each do |muf|
    #         output <<
    #             {
    #               :uri =>   muf.muf_url,
    #               :expression => muf.create_gooddata_muf_representation(pid)
    #             }
    #       end
    #     end
    #   end
    #   output
    # end

    def reset_muf
      @mufs.each do |muf|
        muf.values = muf.new_values
        muf.new_values = {}
      end
    end

    def clear_mufs
      @mufs = []
    end


    state_machine :state, :initial => :start do
      state :start
      state :create
      state :ok
      state :changed

      event :change do
        transition [:start,:ok,:create] => :changed
      end

      event :clear do
        transition all => :start
      end



    end




  end

end