# encoding: UTF-8

# Copyright (c) 2009, GoodData Corporation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
# Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
# Neither the name of the GoodData Corporation nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

module PowerByHelper


  class Project

    attr_accessor :name_prefix,:token,:template

    def initialize()
      load_data_structure()
    end

    def load_data_structure()
      data_file_path = Settings.deployment_project_data_file_name
      data_mapping = Settings.deployment_project["data"]["mapping"]

      #In case of remote file location, lets download file to local first
      if (Settings.deployment_project_data_type == "webdav")
        remote_filename = data_file_path.split("/").last
        if (Helper.check_file_on_webdav("processing/" + remote_filename))
          @@log.info "Found file in processing folder #{remote_filename}, reusing"
          Helper.download_file_from_webdav("processing/" + remote_filename,Settings.default_project_data_file_name)
        else
          @@log.info "Downloading file #{data_file_path}"
          Helper.download_file_from_webdav(data_file_path,Settings.default_project_data_file_name)
          Helper.move_file_to_other_folder(data_file_path,"processing/" + remote_filename)
        end
        data_file_path = Settings.default_project_data_file_name
      end
      fail "Project data file don't exists" unless File.exists?(data_file_path)
      fail "Project mapping don't have all necessery fields" unless data_mapping.has_key?("project_name") and data_mapping.has_key?("ident")
      fail "You have not specified template for project creation. Project would have been created empty" if Helper.blank?(Settings.deployment_project["template"])
      fail "You have not specified token for project creation." if Helper.blank?(Settings.deployment_project["token"])



      if (Validation.validate_project_file(data_file_path))
        fail "The validation of project file has failed. Please fix the source file and run the tool again"
      end

      Persistent.init_project
      Persistent.init_project_custom_params

      file_rows = []

      FasterCSV.foreach(data_file_path, {:headers => true, :skip_blanks => true}) do |csv_obj|
        fail "One of the project names is empty" if Helper.blank?(csv_obj[data_mapping["project_name"]]) or Helper.blank?(csv_obj[data_mapping["ident"]])
        file_rows.push(csv_obj)
      end

      file_rows.each do |csv_obj|
        Persistent.change_project_status(csv_obj[data_mapping["ident"]],ProjectData.NEW,{"ident" => csv_obj[data_mapping["ident"]], "project_name" => csv_obj[data_mapping["project_name"]], "summary" => csv_obj[data_mapping["summary"]]})

        #key value mapping
        param_values = []
        Persistent.custom_params_names.each do |value|
          param_values.push({value.keys.first => csv_obj[value.values.first]})
        end
        Persistent.project_custom_params.push({csv_obj[data_mapping["ident"]] => param_values})
      end

      Persistent.project_data.each do |p|
        if (p.status != ProjectData.DISABLED)
          row = file_rows.find{|r| r[data_mapping["ident"]] == p.ident}
          if (row.nil?)
            Persistent.change_project_status(p.ident,ProjectData.TO_DISABLE,nil)
          end
        end
      end

      @@log.info "Persistent storage for project provisioning initialized"
    end


    def load_data_structure_maintenance()
      data_file_path = Settings.deployment_project_data_file_name
      fail "Project data file don't exists" unless File.exists?(data_file_path)

      Persistent.init_project
      @@log.info "Persistent storage for project maintenance initialized"
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
          Persistent.change_project_status(p.ident,ProjectData.CREATED,{"project_pid" => project.obj_id})
          Persistent.store_project
          @@log.info "Project created!"
        end

        while (Persistent.get_projects_by_status(ProjectData.CREATED).count >= creation_window)
          @@log.info "Waiting till all created project are provisioned"
          Persistent.get_projects_by_status(ProjectData.CREATED).each do |for_check|
            project_status = GoodData::Project[for_check.project_pid]
            if !(project_status.to_json['content']['state'] =~ /^(PREPARING|PREPARED|LOADING)$/)
              Persistent.change_project_status(for_check.ident,ProjectData.OK,nil)
              Persistent.store_project
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
            Persistent.change_project_status(for_check.ident,ProjectData.OK,nil)
            Persistent.store_project
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
          Persistent.store_project
        end

        if (p.status == ProjectData.TO_DISABLE)
          # Here we only mark project as disabled, users will be disabled in user provisioning part
          Persistent.change_project_status(p.ident,ProjectData.DISABLED,nil)
          Persistent.store_project
        end
      end
    end

    def delete_projects()
      Persistent.project_data.each do |p|
        if (p.status == ProjectData.TO_DISABLE)
          # We will delete all project which are set to delete
          delete_project(p)
        end
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
      Persistent.store_user_project
      Persistent.store_etl
      Persistent.store_project

    end


    def maintenance_execute_maql(maql_file)

      #Load MAQL from file
      fail "MAQL file not exist" if !File.exist?(maql_file)
      maql = File.read(maql_file)

      Persistent.project_data.each do |project|
        response = MaintenanceHelper.execute_maql(project,maql)
      end
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

    attr_accessor :ident,:project_pid,:project_name,:status,:summary,:to_delete,:disabled_at,:maintenance

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





    def initialize(status,data)
      @status = status
      @ident = data["ident"] if !data["ident"].nil?
      @project_pid = data["project_pid"] if !data["project_pid"].nil?
      @project_name = data["project_name"] if !data["project_name"].nil?
      @summary = data["summary"] if !data["summary"].nil?
      @disabled_at = data["disabled_at"] if !data["disabled_at"].nil?
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