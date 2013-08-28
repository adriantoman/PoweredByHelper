module PowerByHelper


  class User
    def initialize()
      load_data_structure()
    end

    def load_data_structure()

      user_creation_mapping = Settings.deployment_user_creation["mapping"]
      user_synchronization_mapping = Settings.deployment_user_project_synchronization["mapping"]

      #Checks
      fail "User data file don't exists" unless File.exists?(Settings.deployment_user_creation["source"])
      fail "User project data file don't exists" unless File.exists?(Settings.deployment_user_project_synchronization["source"])
      fail "User creation mapping don't have all necessery fields" unless user_creation_mapping.has_key?("login") and user_creation_mapping.has_key?("first_name") and user_creation_mapping.has_key?("last_name")
      fail "User project synchronization  mapping don't have all necessery fields" unless user_synchronization_mapping.has_key?("ident") and user_synchronization_mapping.has_key?("login") and user_synchronization_mapping.has_key?("role") and user_synchronization_mapping.has_key?("notification")


      #Initializations
      Persistent.init_user
      Persistent.init_roles

      password_mapping = user_creation_mapping["password"] || "password"
      admin_mapping = user_creation_mapping["admin"] || "admin"


      FasterCSV.foreach(Settings.deployment_user_creation["source"], :headers => true) do |csv_obj|

        user_data = UserData.new({"login" => csv_obj[user_creation_mapping["login"]], "first_name" => csv_obj[user_creation_mapping["first_name"]], "last_name" => csv_obj[user_creation_mapping["last_name"]], "status" => UserData.NEW})
        user_data.password = csv_obj[password_mapping] || rand(10000000000000).to_s

        if (!Helper.blank?(csv_obj[admin_mapping]) and csv_obj[admin_mapping].downcase == "1")
          user_data.admin = true
        else
          user_data.admin = false
        end

        Persistent.merge_user(user_data)
      end
      Persistent.store_user


      FasterCSV.foreach(Settings.deployment_user_project_synchronization["source"], :headers => true) do |csv_obj|

        ident = csv_obj[user_synchronization_mapping["ident"]]

        project_pid = Persistent.get_project_by_ident(ident)

        fail "There is no project with specified ID #{ident}" if project_pid.nil?

        project_pid = project_pid.project_pid

        role = csv_obj[user_synchronization_mapping["role"]]
        check = Helper.roles.find{|r| r.downcase == role.downcase}
        fail "This role does not exist in Gooddata" if check.nil?

        login = csv_obj[user_synchronization_mapping["login"]].downcase
        notification = csv_obj[user_synchronization_mapping["notification"]].downcase == "1" ? true : false

        user_project_data = UserProjectData.new({"project_pid" => project_pid,"role" => role, "notification" => notification})

        Persistent.merge_user_project(login,user_project_data)
      end
      Persistent.store_user

      admin_users = Persistent.get_users_by_admin
      projects = Persistent.get_projects
      admin_users.each do |admin|
        admin_data = admin.values.first
        projects.each do |p|
          user_project_data = UserProjectData.new({"project_pid" => p.project_pid,"role" => "adminRole", "notification" => false})
        end




      end




    end


    def create_new_users
      users_to_create = Persistent.get_users_by_status(UserData.NEW)
      users_to_create.each do |v|
        user_data = v.values.first
        user_data = UserHelper.create_user_in_domain(Settings.deployment_user_domain,user_data)
        Persistent.merge_user(user_data) if !user_data.nil?
      end
      Persistent.store_user
    end

    def invite_users
      Persistent.user_data.each do |v|
          user_data = v.values.first
          UserHelper.invite_user(user_data)
      end
      Persistent.store_user
    end

    def add_users

    end


    def disable_users_in_project(pid)

    end

    def update_user_role(pid)

    end









  end



  class UserData
    attr_accessor :uri,:login,:first_name,:last_name,:user_project_mapping,:password,:admin,:status


    def self.NEW
      "NEW"
    end

    def self.CREATED
      "CREATED"
    end

    def initialize(data)
      @user_project_mapping = []
      @uri = data["uri"] || ""
      @login = data["login"]
      @first_name = data["first_name"]
      @last_name = data["last_name"]
      @password = data["password"]
      @admin = data["admin"]
      @status = data["status"] || UserData.NEW
      if (!data["user_project_mapping"].nil?)
        data["user_project_mapping"].each do |user_project|
          @user_project_mapping.push(UserProjectData.new(user_project))
        end
      end
    end


    def add_or_update_user_project_mapping(user_project)
      user_check = @user_project_mapping.find{|up| up.project_pid == user_project.project_pid }
      if (user_check.nil?)
        user_project.status = UserProjectData.NEW
        @user_project_mapping.push(user_project)
      else
        @user_project_mapping.collect! do |up|
          if (up.project_pid == user_project.project_pid)

            if (up.role != user_project.role)
              up.role = user_project.role
              up.status = UserProjectData.CHANGED
            end
            # This will happen in case that tool will fall in middle of operation and new status will be loaded from PersistentFile
            if (user_project.status == UserProjectData.NEW)
              # The user is NEW and for some reason was not created in previous run.
              up.status = UserProjectData.NEW
            elsif (user_project.status.nil?)
              if (up.status == UserProjectData.DISABLED)
                # The user was disabled in project,but now it should be enabled again
                up.status = UserProjectData.CHANGED
              else
                # The user was in Persistent storage and it should stay unchanged
                up.status = UserProjectData.OK
              end

            end
            if (!up.notification_send and user_project.notification_send)
              # The user was invited to project and now it is OK
              up.status = UserProjectData.OK
              up.notification_send = true
            end
          end
          up
        end
      end

    end

    def generate_mapping
       data = []
       @user_project_mapping.each do |e|
         data.push(e.to_json)
       end
       data
    end


    def to_json
      {
          "login" => @login,
          "uri" => @uri,
          "first_name" => @first_name,
          "last_name" => @last_name,
          "status" => @status,
          "user_project_mapping" => generate_mapping
      }

    end

  end


  class UserProjectData

    attr_accessor :project_pid,:role,:status,:notification, :notification_send


    def self.NEW
      "NEW"
    end

    def self.CHANGED
      "CHANGED"
    end

    def self.OK
      "OK"
    end

    def self.TO_DISABLE
      "TO_DISABLE"
    end

    def self.DISABLED
      "DISABLED"
    end




    def initialize(data)
        @project_pid = data["project_pid"]
        @role = data["role"]
        # When we are loading status from storage, we will mark it as TO_DISABLE. If it will be in user_project file or it will be for admin user, it will be updated to OK
        if (data["status"] == UserProjectData.OK)
          @status = UserProjectData.TO_DISABLE
        else
          @status = data["status"]
        end
        @notification = data["notification"]
        @notification_send = data["notification_send"] || false

    end

    def to_json
      {
          "project_pid" => @project_pid,
          "role" => @role,
          "status" => @status,
          "notification" => @notification,
          "notification_send" => @notification_send
      }
    end

  end


end

