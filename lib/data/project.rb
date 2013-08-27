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

      FasterCSV.foreach(data_file_path, :headers => true) do |csv_obj|
        fail "One of the project names is empty" if Helper.blank?(csv_obj[data_mapping["project_name"]]) or Helper.blank?(csv_obj[data_mapping["ident"]])
        project_data = ProjectData.new({"ident" => csv_obj[data_mapping["ident"]], "project_name" => csv_obj[data_mapping["project_name"]], "summary" => csv_obj[data_mapping["summary"]]})
        Persistent.merge_project(project_data)
      end
    end


    def create_projects
      creation_window = Settings.deployment_project["creation_window"] || 1

      Persistent.project_data.each do |p|

        if (Helper.blank?(p.status))
          @@log.info "Creating project:"
          @@log.ap p

          json = {
              'meta' => {
                  'title' => Settings.deployment_project["name_prefix"] +  p.project_name,
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
          Persistent.update_project(p)
        end

        while (Persistent.get_project_by_status(ProjectData.CREATED).count >= creation_window)
          @@log.info "Checking provisioned projects"
          Persistent.get_project_by_status(ProjectData.CREATED).each do |for_check|
            project_status = GoodData::Project[for_check.project_pid]
            if !(project_status.to_json['content']['state'] =~ /^(PREPARING|PREPARED|LOADING)$/)
              for_check.status = ProjectData.LOAD_FINISHED
              Persistent.update_project(for_check)
            end
          end

          if (Persistent.get_project_by_status(ProjectData.CREATED).count >= creation_window)
            @@log.info "Sleeping"
            sleep(10)
            @@log.info "Waking up"
          end
        end
      end
    end

    def disable_project(pid)


    end

    def delete_project(pid)

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

    def self.IN_PROGRESS
      "IN_PROGRESS"
    end

    def self.LOAD_FINISHED
      "LOAD_FINISHED"
    end

    def initialize(data)
      @ident = data["ident"]
      @project_pid = data["project_pid"]
      @project_name = data["project_name"]
      @status = data["status"]
      @summary = data["summary"]
      @to_delete = true
      @disabled_at = data["disabled_at"]
    end

    def self.header
      ["ident","project_pid","project_name","status","disabled_at"]
    end

    def to_a
      [@ident,@project_pid,@project_name,@status,@disabled_at]
    end



  end





end