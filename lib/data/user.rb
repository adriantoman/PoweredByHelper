module PowerByHelper


  class User
    def initialize()
      load_data_structure()
    end

    def load_data_structure()

      user_creation_mapping = Settings.deployment_user_creation["mapping"]
      user_synchronization_mapping = Settings.deployment_user_project_synchronization["mapping"]


      fail "User data file don't exists" unless File.exists?(Settings.deployment_user_creation["source"])
      fail "User project data file don't exists" unless File.exists?(Settings.deployment_user_project_synchronization["source"])
      fail "User creation mapping don't have all necessery fields" unless user_creation_mapping.has_key?("login") and user_creation_mapping.has_key?("first_name") and user_creation_mapping.has_key?("last_name")
      fail "User project synchronization  mapping don't have all necessery fields" unless user_synchronization_mapping.has_key?("ident") and user_synchronization_mapping.has_key?("login") and user_synchronization_mapping.has_key?("role") and user_synchronization_mapping.has_key?("notification")

      Persistent.init_user

      password_mapping = user_creation_mapping["password"] || "password"
      admin_mapping = user_creation_mapping["admin"] || "admin"


      FasterCSV.foreach(Settings.deployment_user_creation["source"], :headers => true) do |csv_obj|

        user_data = UserData.new({"login" => csv_obj[user_creation_mapping["login"]], "first_name" => csv_obj[user_creation_mapping["first_name"]], "last_name" => csv_obj[user_creation_mapping["last_name"]], "status" => UserData.NEW})
        user_data.password = csv_obj[password_mapping] || rand(10000000000000).to_s

        if (!Helper.blank?(csv_obj[admin_mapping]) and csv_obj[admin_mapping].downcase == "yes")
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
        fail "There is no project with specified ID #{ident}"

        role = csv_obj[user_synchronization_mapping["role"]]
        check = Helper.roles.find{|r| r.downcase == role}
        fail "This role does not exist in Gooddata" if check.nil?

        login = csv_obj[user_synchronization_mapping["login"]].downcase
        notification = csv_obj[user_synchronization_mapping["notification"]].downcase == "yes" ? true : false

        user_project_data = UserProjectData.new({"project_pid" => project_pid,"role" => role, "status" => UserProjectData.NEW , "notification" => notification})

      end





      #FasterCSV.foreach(data_file_path, :headers => true) do |csv_obj|
      #  fail "One of the project names is empty" if Helper.blank?(csv_obj[data_mapping["project_name"]]) or Helper.blank?(csv_obj[data_mapping["ident"]])
      #  project_data = ProjectData.new({"ident" => csv_obj[data_mapping["ident"]], "project_name" => csv_obj[data_mapping["project_name"]], "summary" => csv_obj[data_mapping["summary"]]})
      #  Persistent.merge_project(project_data)
      #end
    end




  end



  class UserData
    attr_accessor :uri,:login,:first_name,:last_name,:user_project_mapping,:password


    def self.NEW
      "NEW"
    end

    def initialize(data)
      @user_project_mapping = []
      @uri = data["uri"]
      @login = data["login"]
      @first_name = data["first_name"]
      @last_name = data["last_name"]
      @password = data["password"]
      @admin = data["admin"]
      @status = data["status"] || UserData.NEW
      if (data["user_project_mapping"].nil?)
        data["user_project_mapping"].each do |user_project|
          @user_project_mapping.push(UserProjectData.new(user_project))
        end
      end
    end


    def add_or_update_user_project_mapping(user_project)
      user_project = @user_project_mapping.find{|up| up.project_pid == user_project.project_pid }
      if (user_project.nil?)
        @user_project_mapping.push(user_project)
      else
        @user_project_mapping.collect! do |up|
          if (up.login == user_project.login)
            if (up.role != user_project.role)
              up.role = user_project.role
              up.status = UserProjectData.CHANGED
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
          "user_project_mapping" => generate_mapping
      }

    end

  end


  class UserProjectData

    attr_accessor :project_pid,:role,:status,:notified


    def self.NEW
      "NEW"
    end

    def self.CHANGED
      "CHANGED"
    end

    def self.OK
      "OK"
    end



    def initialize(data)
        @project_pid = data["project_pid"]
        @role = data["role"]
        @status = data["status"]
        @notification = data["notification"]
        @notification_send = data["notification_send"]

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

