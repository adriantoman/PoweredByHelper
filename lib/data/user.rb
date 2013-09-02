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

      # Load info about users - domain file - representing users which should be in domain and merge it with info in Persistent storage
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

      # Load info about user-project mapping and merge it with information from Persistent Storage
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
        internal_role = "external"
        if (!user_synchronization_mapping["internal_role"].nil?)
          internal_role = csv_obj[user_synchronization_mapping["internal_role"]].downcase
        end
        user_project_data = UserProjectData.new({"project_pid" => project_pid,"role" => role, "notification" => notification,"internal_role" => internal_role,status => UserProjectData.NEW})
        Persistent.merge_user_project(login,user_project_data)
      end
      Persistent.store_user

      # Find all admin users and make them admin in all of the projects - merge this information with persistent storage
      admin_users = Persistent.get_users_by_admin
      projects = Persistent.get_projects

      admin_users.each do |admin|
        admin_data = admin.values.first
        projects.each do |p|
          user_project_data = UserProjectData.new({"project_pid" => p.project_pid,"role" => "adminRole", "notification" => false, "internal_role" => "internal",status => UserProjectData.NEW})
          Persistent.merge_user_project(admin_data.login,user_project_data)
        end
      end
      Persistent.store_user


      # We are supporting disable feature on projects
      # DISABLED project for us is project, in which all users (except of users with role_internal == internal) are disabled
      projects_to_disable = Persistent.get_projects_by_status(ProjectData.DISABLED)

      Persistent.user_data.each do |u|
        user_data = u.values.first
        user_data.user_project_mapping.each do |user_project|
          is_disabled = !(projects_to_disable.find{|p| p.project_pid = user_project.pid}.nil?)
          if (is_disabled and user_project.internal_role != "internal")
            user_project.status = UserProjectData.TO_DISABLE_BY_PROJECT
            Persistent.merge_user_project(user_data.login,user_project)
          end
        end
      end

      @log.info "Persistent storage for user provisioning initialized"


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

    end

    def add_users
      Persistent.user_data.each do |v|
        user_data = v.values.first
        UserHelper.add_user(user_data)
      end
      Persistent.store_user
    end


    def disable_users
      Persistent.user_data.each do |v|
        user_data = v.values.first
        UserHelper.disable_user(user_data)
      end
      Persistent.store_user
    end

    def update_users
      Persistent.user_data.each do |v|
        user_data = v.values.first
        UserHelper.update_user(user_data)
      end
      Persistent.store_user

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
        @user_project_mapping.push(user_project)
      else
        @user_project_mapping.collect! do |up|
          if (up.project_pid == user_project.project_pid)
            if (up.status == UserProjectData.TO_DISABLE and user_project.status == UserProjectData.NEW)
              @@log.debug "status OK"
              up.status = UserProjectData.OK
            elsif (up.status == UserProjectData.DISABLED and user_project.status == UserProjectData.NEW)
              @@log.debug "Project again in source file - status CHANGED"
              up.status = UserProjectData.CHANGED
            elsif (up.status == UserProjectData.OK and up.role != user_project.role)
              @@log.debug "Role change detected - status CHANGED"
              up.status = UserProjectData.CHANGED
            elsif (user_project.status == UserProjectData.OK and !up.notification_send and user_project.notification_send)
              @@log.debug "User was invited to project - status OK"
              up.status = UserProjectData.OK
              up.notification_send = true
            elsif (up.status == UserProjectData.OK and user_project.status == UserProjectData.TO_DISABLE_BY_PROJECT)
              @@log.debug "User was in disabled project - disabling it"
              up.status = UserProjectData.TO_DISABLE
            elsif (up.status == UserProjectData.CHANGED and user_project.status == UserProjectData.TO_DISABLE_BY_PROJECT)
              @@log.debug "User was in disabled project, but someone have left him in project-user mapping file - leaving it disabled"
              up.status = UserProjectData.DISABLED
            else
              up.status = user_project.status
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

    attr_accessor :project_pid,:role,:status,:notification, :notification_send, :internal_role


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

    def self.TO_DISABLE_BY_PROJECT
      "TO_DISABLE_BY_PROJECT"
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
        @internal_role = data["internal_role"] || "external"
    end

    def to_json
      {
          "project_pid" => @project_pid,
          "role" => @role,
          "status" => @status,
          "notification" => @notification,
          "notification_send" => @notification_send,
          "internal_role" => @internal_role
      }
    end

  end


end

