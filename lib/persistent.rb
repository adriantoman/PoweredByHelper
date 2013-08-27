module PowerByHelper

  class Persistent

    class << self

      attr_accessor :project_data,:etl_data
      # project section

      def init_project()
        @project_data = []
        load_project()
      end

      def init_etl()
        @etl_data = []
        load_etl()
      end

      def init_user()
        @user_data = []
        load_user()
      end


      def store_project
        FileUtils.mkdir_p Settings.storage_project_source if !File.exists?(Settings.storage_project_source)
        FasterCSV.open(Settings.storage_project_source, 'w',:quote_char => '"') do |csv|
          csv << ProjectData.header
          @project_data.each do |d|
            csv << d.to_a
          end
        end
      end

      def store_etl
        FileUtils.mkdir_p File.dirname(Settings.storage_etl_source) if !File.exists?(Settings.storage_etl_source)
        FasterCSV.open(Settings.storage_etl_source, 'w',:quote_char => '"') do |csv|
          csv << EtlData.header
          @etl_data.each do |d|
            csv << d.to_a
          end
        end
      end


      def store_user
        FileUtils.mkdir_p File.dirname(Settings.storage_user_source) if !File.exists?(Settings.storage_user_source)
        File.open(Settings.storage_user_source,"w") do |f|
          hash = {
              "user_data" => @user_data.map {|u| { u.login => u.to_json}}
          }
          f.write(JSON.pretty_generate(hash))
        end
      end


      def load_project
        if (File.exists?(Settings.storage_project_source))
          FasterCSV.foreach(Settings.storage_project_source, :headers => true,:quote_char => '"') do |csv_obj|
            project = ProjectData.new(csv_obj)
            @project_data.push(project)
          end
        end
      end


      def load_user
        if (File.exists?(Settings.storage_user_source))
          File.open( Settings.storage_user_source, "r" ) do |f|
            json = JSON.load( f )
            if (!json["user_data"].nil?)
              json["user_data"].each do |key,value|
                @user_data.push({json["user_data"].key => UserData.new(value)})
              end
            end
          end
        end
      end

      def load_etl
        if (File.exists?(Settings.storage_etl_source))
          FasterCSV.foreach(Settings.storage_etl_source, :headers => true,:quote_char => '"') do |csv_obj|
            etl = EtlData.new(csv_obj)
            @etl_data.push(etl)
          end
        end
      end



      def update_project(project_data)
        @project_data.collect! do |d|
          if (d.ident == project_data.ident )
            project_data
          else
            d
          end
        end
        store_project
      end


      def update_etl(etl_data)
        etl_test = @etl_data.find{|d| d.project_pid == etl_data.project_pid}
        if (etl_test.nil?)
          @etl_data.push(etl_data)
        else
          @etl_data.collect! do |d|
            if (d.ident == etl_data.ident )
              etl_data
            else
              d
            end
          end
        end
        store_etl
      end

      def merge_project(data)
        if (@project_data.find{|p| p.ident == data.ident }.nil?)
          @project_data.push(data)
        else
          @project_data.collect! do |d|
            if (d.ident == data.ident )
              data.project_pid = d.project_pid
              data.status = d.status
              data.to_delete = false
              data
            else
              d
            end
          end
        end
        store_project
      end

      def merge_user(data)
        if (@user_data.find{|p| p.key == data.login }.nil?)
          @user_data.push({data.login => data})
        else
          @user_data.collect! do |d|
            if (d.key == data.login )
              d.admin = data.admin
              data
            else
              d
            end
          end
        end
      end

      def merge_user_project(login,user_project_data)
        user = @user_data.find{|u| u.key == login}
        if (user.nil?)
          user.add_or_update_user_project_mapping(user_project_data)
        else
          fail "You are looking for user in user data, but you have not found it. This should not happen"
        end




      end









      def get_project_by_status(status)
        @project_data.find_all{|d| d.status == status}
      end

      def get_project_by_project_pid(project_pid)
        @project_data.find{|d| d.project_pid == project_pid}
      end

      def get_project_by_ident(ident)
        @project_data.find{|d| d.ident == ident}
      end

      def get_etl_by_project_pid(project_pid)
        @etl_data.find{|d| d.project_pid == project_pid}
      end

      def reset_schedule_update
        @etl_data.collect! do |d|
          d.is_updated_schedule = false
          d
        end
      end

      def reset_notification_update
        @etl_data.collect! do |d|
          d.is_updated_notification = false
          d
        end
      end

      def exists_one_nonupdated_schedule?
        etl = @etl_data.find {|s| s.is_updated_schedule == false}
        !etl.nil?
      end

      def exists_one_nonupdated_notification?
        etl = @etl_data.find {|s| s.is_updated_notification == false}
        !etl.nil?
      end



    end


  end


end