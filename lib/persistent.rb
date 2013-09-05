module PowerByHelper

  class Persistent

    class << self

      attr_accessor :project_data,:etl_data,:user_data,:roles
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
        if (@user_data.nil?)
          @user_data = []
          load_user()
        end
      end

      def init_roles()
        @roles = {}
        load_roles()
      end



      def store_project
        FileUtils.mkdir_p File.dirname(Settings.storage_project_source) if !File.exists?(Settings.storage_project_source)
        FasterCSV.open(Settings.storage_project_source, 'w',:quote_char => '"') do |csv|
          csv << ProjectData.header
          @project_data.each do |d|
            csv << d.to_a
          end
        end
      end

      def store_etl
        if (!etl_data.nil?)
          FileUtils.mkdir_p File.dirname(Settings.storage_etl_source) if !File.exists?(Settings.storage_etl_source)
          FasterCSV.open(Settings.storage_etl_source, 'w',:quote_char => '"') do |csv|
            csv << EtlData.header
            @etl_data.each do |d|
              csv << d.to_a
            end
          end
        end
      end


      def store_user
        if (!@user_data.nil?)
          FileUtils.mkdir_p File.dirname(Settings.storage_user_source) if !File.exists?(Settings.storage_user_source)
          File.open(Settings.storage_user_source,"w") do |f|
            hash = {
                "user_data" => @user_data.map {|u| {  u.keys.first => u.values.first.to_json}}
            }
            f.write(JSON.pretty_generate(hash))
          end
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
            if (!json.nil? and !json["user_data"].nil?)
              json["user_data"].each do |u|
                @user_data.push({u.keys.first => UserData.new(u.values.first)})
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


      def load_roles
        # Lets load from gooddata the rolesId to roleName mapping
        # We will take first project
        pid = @project_data.first.project_pid
        fail "The project are not initialized. You cannot load roles without projects" if pid.nil?

          roles_response = GoodData.get("/gdc/projects/#{pid}/roles")
        roles_response["projectRoles"]["roles"].each do |role_uri|
          r = GoodData.get(role_uri)
          identifier = r["projectRole"]["meta"]["identifier"]
          @roles[identifier] = {
              "uri"      => role_uri.gsub!(pid,"%PID%")
          }
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
              # Project was loaded from persistent storage and now it is in source file - nothing to do
              if (data.status == ProjectData.NEW and d.status == ProjectData.TO_DISABLE)
                @@log.debug "Project - setting status to OK - project found in source file"
                d.status = ProjectData.OK
              elsif (data.status == ProjectData.CREATED and d.status == ProjectData.NEW)
                @@log.debug "Project - setting status to CREATED - project created"
                d.status = ProjectData.CREATED
                d.project_pid = d.project_pid
              elsif (data.status == ProjectData.DISABLED and d.status == ProjectData.TO_DISABLE)
                @@log.debug "Project - project was TO_DISABLE waiting disable and now is DISABLED"
                d.status = ProjectData.DISABLED
                d.disabled_at = DateTime.now().strftime("%Y-%m-%d %H:%M:%S")
              elsif (data.status == ProjectData.DELETED and (d.status == ProjectData.DISABLED or d.status == ProjectData.TO_DISABLE))
                @@log.debug "Project - project was DISABLED or TO_DISABLE and force delete setting is enabled or project was disabled for long time"
                d.status = ProjectData.DELETED
              elsif (data.status == ProjectData.NEW and d.status == ProjectData.DISABLED)
                @@log.debug "Project - project was disabled, but it is again in provisiong file"
                d.status = ProjectData.OK
              elsif (data.status == ProjectData.NEW and d.status == ProjectData.DELETED)
                @@log.debug "Project - project was deleted, but it is again in provisioning file"
                d.status = ProjectData.NEW
              else
                @@log.debug "Project - default transition from #{d.status} to #{data.status}"
                d.status = data.status
              end
            end
            d
          end
        end
        store_project
      end

      def merge_user(data)
        user = @user_data.find do |u|
          u.keys.first == data.login
        end
        if (user.nil?)
          @user_data.push({data.login => data})
        else
          @user_data.collect! do |d|
            if (d.keys.first == data.login )
              user_data = d.values.first
              user_data.admin = data.admin
              user_data.password = data.password
              user_data.uri = data.uri if !Helper.blank?(data.uri)
              d[d.keys.first] = user_data
              d
            else
              d
            end
          end
        end
      end

      def merge_user_project(login,user_project_data)
        user = @user_data.find{|u| u.keys.first == login}
        if (!user.nil?)
          user.values.first.add_or_update_user_project_mapping(login,user_project_data)
        else
          fail "You are looking for user in user data, but you have not found it. This should not happen"
        end

      end











      def get_projects_by_status(status)
        @project_data.find_all{|d| d.status == status}
      end

      def get_projects
        @project_data
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

      def get_users_by_status(status)
        @user_data.find_all{|e| e.values.first.status == status}
      end

      def get_users_by_admin
        @user_data.find_all{|e| e.values.first.admin == true}
      end

      def get_role_uri_by_name(name,pid)

        if (@roles.has_key?(name))
          @roles[name]["uri"].gsub("%PID%",pid)
        else
          @log.warn "Role #{name} is not valid GoodData role. Setting role to readOnlyUserRole by default"
          @roles["readOnlyUserRole"]["uri"].gsub("%PID%",pid)
        end
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


      def delete_project_by_project_pid(project_pid)
        project_data.delete_if {|p| p.project_pid == project_pid}
      end

      def delete_etl_by_project_pid(project_pid)
        @etl_data.delete_if {|e| e.project_pid == project_pid }
      end

      def delete_user_project_by_project_pid(project_pid)
        if (!@user_data.nil?)
          @user_data.collect! do |u|
            data = u.values.first
            data.user_project_mapping = data.user_project_mapping.delete_if {|up| up.project_pid == project_pid}
            pp data.user_project_mapping

            u[u.keys.first] = data
            u
          end
        end

      end



    end


  end


end