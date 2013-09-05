module PowerByHelper


  class Project

    attr_accessor :name_prefix,:token,:template

    def initialize()
      load_data_structure()
    end

    def load_data_structure()
      data_file_path = Settings.deployment_project["data"]["file_name"]
      data_mapping = Settings.deployment_project["data"]["mapping"]

      fail "Project data file don't exists" unless File.exists?(data_file_path)
      fail "Project mapping don't have all necessery fields" unless data_mapping.has_key?("project_name") and data_mapping.has_key?("ident")
      fail "You have not specified template for project creation. Project would have been created empty" if Helper.blank?(Settings.deployment_project["template"])
      fail "You have not specified token for project creation." if Helper.blank?(Settings.deployment_project["token"])

      Persistent.init_project

      FasterCSV.foreach(data_file_path, {:headers => true, :skip_blanks => true}) do |csv_obj|
        fail "One of the project names is empty" if Helper.blank?(csv_obj[data_mapping["project_name"]]) or Helper.blank?(csv_obj[data_mapping["ident"]])
        project_data = ProjectData.new({"ident" => csv_obj[data_mapping["ident"]], "project_name" => csv_obj[data_mapping["project_name"]], "summary" => csv_obj[data_mapping["summary"]],"status" => ProjectData.NEW})
        Persistent.merge_project(project_data)
      end

      @@log.info "Persistent storage for project provisioning initialized"

    end


    def create_projects
      creation_window = Settings.deployment_project["creation_window"] || 3

      @@log.info "Creation window is set to #{creation_window} (Number of  simultaneous created projects)"
      Persistent.project_data.each do |p|

        if (p.status == ProjectData.NEW)
          @@log.info "Creating project - #{p.project_name} (#{p.ident})"

          json = {
              'meta' => {
                  'title' => Settings.deployment_project_name_prefix +  p.project_name,
                  'summary' => p.summary || "",
                  'projectTemplate' => Settings.deployment_project["template"]
              },
              'content' => {
                  'guidedNavigation' => 1,
                  'driver' => 'Pg',
                  'authorizationToken' => Settings.deployment_project["token"]
              }
          }

          project = GoodData::Project.new json
          project.save
          p.project_pid = project.obj_id

          p.status = ProjectData.CREATED
          Persistent.merge_project(p)
          @@log.info "Project created!"
        end

        while (Persistent.get_projects_by_status(ProjectData.CREATED).count >= creation_window)
          @@log.info "Waiting till all created project are provisioned"
          Persistent.get_projects_by_status(ProjectData.CREATED).each do |for_check|
            project_status = GoodData::Project[for_check.project_pid]
            if !(project_status.to_json['content']['state'] =~ /^(PREPARING|PREPARED|LOADING)$/)
              for_check.status = ProjectData.OK
              Persistent.merge_project(for_check)
            end
          end

          if (Persistent.get_projects_by_status(ProjectData.CREATED).count >= creation_window)
            @@log.info "Waiting - START"
            sleep(10)
            @@log.info "Waiting - STOP"
          end
        end
      end


      while (Persistent.get_projects_by_status(ProjectData.CREATED).count > 0)
        @@log.info "Waiting till all created project are provisioned"
        Persistent.get_projects_by_status(ProjectData.CREATED).each do |for_check|
          project_status = GoodData::Project[for_check.project_pid]
          if !(project_status.to_json['content']['state'] =~ /^(PREPARING|PREPARED|LOADING)$/)
            for_check.status = ProjectData.OK
            Persistent.merge_project(for_check)
          end
        end

        if (Persistent.get_projects_by_status(ProjectData.CREATED).count > 0)
          @@log.info "Waiting - START"
          sleep(10)
          @@log.info "Waiting - STOP"
        end
      end

    end


    def handle_projects_disable()
      if (Settings.deployment_project_delete.nil? or Settings.deployment_project_delete == "disable_users_first")

        if (Settings.deployment_user.nil?)
          @@log.warn "You have set up, that you want to use user_disable for projects, but you don't have user provisioning section in settings - SKIPPING"
        else
          disable_projects
        end
      elsif (Settings.deployment_project_delete == "force_delete")
        delete_projects
      else
        fail "Unknown project deletions policy. Possible values are: disable_users_first,force_delete"
      end
    end





    def disable_projects()
      Persistent.project_data.each do |p|
        # For some reason there is need of clone here -> because if it is not used ... it updates elements in collections ... which is strange
        p = p.clone
        if (p.status == ProjectData.DISABLED)
          disabled_at = DateTime.strptime(p.disabled_at,"%Y-%m-%d %H:%M:%S")
          store_period = Integer(Settings.deployment_project_disable_duration) || 30

          if ((DateTime.now - disabled_at) > store_period)
            delete_project(p)
          end
        end

        if (p.status == ProjectData.TO_DISABLE)
          # Here we only mark project as disabled, users will be disabled in user provisioning part
          p.status = ProjectData.DISABLED
          Persistent.merge_project(p)
        end
        Persistent.store_project
      end
    end

    def delete_projects()
      Persistent.project_data.each do |p|
        if (p.status == ProjectData.TO_DISABLE)
          # We will delete all project which are set to delete
          delete_project(p)
          Persistent.delete_user_project_by_project_pid(p.project_pid)
          Persistent.delete_etl_by_project_pid(p.project_pid)
          Persistent.delete_project_by_project_pid(p.project_pid)
        end
        Persistent.store_user
        Persistent.store_etl
        Persistent.store_project
      end
    end

    def delete_project(project_data)
      begin
        @@log.info "Deleting project #{project_data.project_name} (#{project_data.project_pid} - #{project_data.ident})"
        GoodData.delete("/gdc/projects/#{project_data.project_pid}")
        Persistent.init_user()
        Persistent.delete_user_project_by_project_pid(project_data.project_pid)
        Persistent.delete_etl_by_project_pid(project_data.project_pid)
        Persistent.delete_project_by_project_pid(project_data.project_pid)
        @@log.info "Project deleted #{project_data.project_name} (#{project_data.project_pid} - #{project_data.ident})"
      rescue RestClient::BadRequest => e
        response = JSON.load(e.response)
        @@log.warn "Project #{project_data.project_pid} could not be deleted. Reason: #{response["error"]["message"]}"
      rescue RestClient::InternalServerError => e
        response = JSON.load(e.response)
        @@log.warn "Project #{project_data.project_pid} could not be deleted. Reason: #{response["error"]["message"]}"
      end
      Persistent.store_user
      Persistent.store_etl
      Persistent.store_project

    end







    def print_test
      @@log.info "Project structure was loaded"
      @@log.info "It has following data loaded in it"
      @@log.info "Name Prefix:#{Settings.deployment_project["name_prefix"]} token:#{Settings.deployment_project["token"]} template: #{Settings.deployment_project["template"]}"
      @@log.ap Persistent.project_data, :info
      @@log.info "\n"
    end





  end


  class ProjectData

    attr_accessor :ident,:project_pid,:project_name,:status,:summary,:to_delete,:disabled_at

    def self.CREATED
      "CREATED"
    end

    def self.NEW
      "NEW"
    end


    def self.IN_PROGRESS
      "IN_PROGRESS"
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

    def self.DELETED
      "DELETED"
    end





    def initialize(data)
      @ident = data["ident"]
      @project_pid = data["project_pid"]
      @project_name = data["project_name"]
      if (data["status"] == ProjectData.OK)
        @status = ProjectData.TO_DISABLE
      else
        @status = data["status"]
      end
      @summary = data["summary"]
      @disabled_at = data["disabled_at"]
      @@log.debug "Setting status to #{@status}"
    end

    def self.header
      ["ident","project_pid","project_name","status","disabled_at"]
    end

    def to_a
      [@ident,@project_pid,@project_name,@status,@disabled_at]
    end



  end





end