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

  class Persistent

    class << self

      attr_accessor :project_data,:etl_data,:user_data,:maintenance_data,:roles,:user_project_data,:project_custom_params,:custom_params_names
      # project section

      def init_project()
        @project_data = []
        load_project()
      end

      def init_project_custom_params
        @project_custom_params = []
        @custom_params_names = []
        # Custom parametrs loading
        Settings.deployment_project["data"]["mapping"].each_pair do |key,value|
          if (key.include?("custom"))
            @custom_params_names.push({key => value })
          end
        end
      end





      def init_etl()
        @etl_data = []
        load_etl()
      end

      def init_user()
        if (@user_data.nil?)
          @user_data = []
          @user_project_data = []
          load_user()
          load_user_project()
        end
      end

      def init_roles()
        @roles = {}
        load_roles()
      end

      def init_maintenance()
        @maintenance_data = []
        load_maintenance()
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
        if (!@etl_data.nil?)
          FileUtils.mkdir_p File.dirname(Settings.storage_etl_source) if !File.exists?(Settings.storage_etl_source)
          FasterCSV.open(Settings.storage_etl_source, 'w',:quote_char => '"') do |csv|
            csv << EtlData.header
            @etl_data.each do |d|
              csv << d.to_a
            end
          end
        end
      end

      def store_maintenance
        FileUtils.mkdir_p File.dirname(Settings.storage_maintenance_source) if !File.exists?(Settings.storage_maintenance_source)
        FasterCSV.open(Settings.storage_maintenance_source, 'w',:quote_char => '"') do |csv|
          csv << MaintenanceData.header
          @maintenance_data.each do |d|
            csv << d.to_a
          end
        end
      end

      def store_user
        if (!@user_data.nil?)
          FileUtils.mkdir_p File.dirname(Settings.storage_user_source) if !File.exists?(Settings.storage_user_source)
          FasterCSV.open(Settings.storage_user_source, 'w',:quote_char => '"') do |csv|
            csv << UserData.header
            @user_data.each do |d|
              csv << d.to_a
            end
          end
        end
      end


      def store_user_project
        if (!@user_project_data.nil?)
          FileUtils.mkdir_p File.dirname(Settings.storage_user_project_source) if !File.exists?(Settings.storage_user_project_source)
          FasterCSV.open(Settings.storage_user_project_source, 'w',:quote_char => '"') do |csv|
            csv << UserProjectData.header
            @user_project_data.each do |d|
              csv << d.to_a
            end
          end
        end
      end

      def load_project
        if (File.exists?(Settings.storage_project_source))
          FasterCSV.foreach(Settings.storage_project_source, :headers => true,:quote_char => '"') do |csv_obj|
            Persistent.change_project_status(csv_obj["ident"],csv_obj["status"],csv_obj)
          end
        end
      end

      def load_maintenance
        if (File.exists?(Settings.storage_maintenance_source))
          FasterCSV.foreach(Settings.storage_maintenance_source, :headers => true,:quote_char => '"') do |csv_obj|
            Persistent.change_maintenance_status(csv_obj["ident"],csv_obj["status"],csv_obj)
          end
        end
      end



      def load_user
        if (File.exists?(Settings.storage_user_source))
          FasterCSV.foreach(Settings.storage_user_source, :headers => true,:quote_char => '"') do |csv_obj|
            if (csv_obj["admin"] == "false")
              csv_obj["admin"] = false
            elsif (csv_obj["admin"] == "true")
              csv_obj["admin"] = true
            end
            Persistent.change_user_status(csv_obj["login"],csv_obj["status"],csv_obj)
          end
        end
      end

      def load_user_project
        if (File.exists?(Settings.storage_user_project_source))
          FasterCSV.foreach(Settings.storage_user_project_source, :headers => true,:quote_char => '"') do |csv_obj|
            if (csv_obj["notification"] == "false")
              csv_obj["notification"] = false
            elsif (csv_obj["notification"] == "true")
              csv_obj["notification"] = true
            end

            if (csv_obj["notification_send"] == "false")
              csv_obj["notification_send"] = false
            elsif (csv_obj["notification_send"] == "true")
              csv_obj["notification_send"] = true
            end
            Persistent.change_user_project_status(csv_obj["login"],csv_obj["project_pid"],csv_obj["status"],csv_obj)
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
        @@log.warn "The project are not initialized. You cannot load roles without projects" if pid.nil?

        if (!pid.nil?)
          roles_response = GoodData.get("/gdc/projects/#{pid}/roles")
          roles_response["projectRoles"]["roles"].each do |role_uri|
          r = GoodData.get(role_uri)
          identifier = r["projectRole"]["meta"]["identifier"]
          @roles[identifier] = {
              "uri"      => role_uri.gsub!(pid,"%PID%")
          }
          end
        end
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



      def change_project_status(id, status, data)
        if (@project_data.find{|p| p.ident == id }.nil?)
          @project_data.push(ProjectData.new(status,data))
        else
          @project_data.collect! do |d|
            if (d.ident == id )
              # Project was loaded from persistent storage and now it is in source file - nothing to do
              if (d.status == status)
                @@log.debug "Same status - do nothing"
              elsif (d.status == ProjectData.DISABLED and status == ProjectData.TO_DISABLE)
                @@log.debug "Project - setting status was DISABLED and we will leave him DISABLED"
                d.status = ProjectData.DISABLED
              elsif (status == ProjectData.TO_DISABLE)
                @@log.debug "Project - setting status was forced to TO_DISABLE status"
                d.status = ProjectData.TO_DISABLE
              elsif (d.status == ProjectData.TO_DISABLE and status == ProjectData.NEW)
                @@log.debug "Project - setting status to OK - project found in source file"
                d.status = ProjectData.OK
              elsif (d.status == ProjectData.NEW and status == ProjectData.CREATED)
                @@log.debug "Project - setting status to CREATED - project created"
                d.status = ProjectData.CREATED
                d.project_pid = data["project_pid"]
              elsif (d.status == ProjectData.TO_DISABLE and status == ProjectData.DISABLED)
                @@log.debug "Project - project was TO_DISABLE waiting disable and now is DISABLED"
                d.status = ProjectData.DISABLED
                d.disabled_at = DateTime.now().strftime("%Y-%m-%d %H:%M:%S")
              elsif ((d.status == ProjectData.DISABLED or d.status == ProjectData.TO_DISABLE) and status == ProjectData.DELETED )
                @@log.debug "Project - project was DISABLED or TO_DISABLE and force delete setting is enabled or project was disabled for long time"
                d.status = ProjectData.DELETED
              elsif (d.status == ProjectData.DISABLED and status == ProjectData.NEW )
                @@log.debug "Project - project was disabled, but it is again in provisiong file"
                d.disabled_at = ""
                d.status = ProjectData.OK
              elsif (d.status == ProjectData.DELETED and status == ProjectData.NEW)
                @@log.debug "Project - project was deleted, but it is again in provisioning file"
                d.status = ProjectData.NEW
              elsif (d.status == ProjectData.CREATED and status == ProjectData.OK)
                @@log.debug "Project - project was CREATED and now is OK"
                d.status = ProjectData.OK
              elsif (d.status == ProjectData.CREATED and status == ProjectData.NEW)
                @@log.debug "Project - project was CREATED and now is CREATED"
                # This could happned when the application will fail and some project will be in CREATED status
                d.status = ProjectData.CREATED
              elsif (d.status == ProjectData.OK and status == ProjectData.NEW)
                @@log.debug "Project - project was OK and now is OK"
                # This could happned when the application will fail and some project will be in CREATED status
                d.status = ProjectData.OK
              else
                fail "Non-supported transition from #{d.status} to #{status}"
              end
            end
            d
          end
        end

      end


      def change_maintenance_status(id, status, data)
        if (@maintenance_data.find{|p| p.project_pid == id }.nil?)
          @maintenance_data.push(MaintenanceData.new(data))
        else
          @maintenance_data.collect! do |d|
            if (d.project_pid == id )
              # Project was loaded from persistent storage and now it is in source file - nothing to do
              if (d.status == status)
                @@log.debug "Same status - do nothing"
              elsif (d.status == MaintenanceData.PROCESSING_MAQL_SCHEDULED and status == MaintenanceData.PROCESSING_MAQL_TASK_CREATED )
                d.task_id = data["task_id"]
                d.status = MaintenanceData.PROCESSING_MAQL_TASK_CREATED
                @@log.debug "Maintenance task #{id} send to Gooddata"
              elsif (d.status == MaintenanceData.PROCESSING_PARTIAL_SCHEDULED and status == MaintenanceData.PROCESSING_PARTIAL_TASK_CREATED )
                d.task_id = data["task_id"]
                d.status = MaintenanceData.PROCESSING_PARTIAL_TASK_CREATED
                @@log.debug "Maintenance task #{id} send to Gooddata"
              elsif (d.status == MaintenanceData.PROCESSING_MAQL_TASK_CREATED and status == MaintenanceData.OK)
                d.status = MaintenanceData.OK
                d.task_id = data["task_id"]
                @@log.debug "Maintenance task #{id} - received positive response"
              elsif (d.status == MaintenanceData.PROCESSING_PARTIAL_TASK_CREATED and status == MaintenanceData.OK)
                d.status = MaintenanceData.OK
                d.task_id = data["task_id"]
                @@log.debug "Maintenance task #{id} - received positive response"
              elsif (status == MaintenanceData.ERROR)
                d.status = MaintenanceData.ERROR
                @@log.debug "Maintenance task #{id} - received negative response (ERROR)"
              elsif (d.status == MaintenanceData.ERROR and (status == MaintenanceData.PROCESSING_PARTIAL_SCHEDULED or status == MaintenanceData.PROCESSING_MAQL_SCHEDULED))
                d.status = status
                d.task_id = nil
                @@log.debug "Maintenance task #{id} - ERROR - setting to proper status - retrying"
              elsif (d.status == MaintenanceData.ERROR)
                @@log.debug "Maintenance task #{id} - ERROR status ignoring all operations"
              else
                fail "Non-supported transition from #{d.status} to #{status}"
              end
            end
            d
          end
        end
      end


      def change_user_status(login,status,data)
        user_check = @user_data.find{|up| up.login == login }
        if (user_check.nil?)
          @user_data.push(UserData.new(status,data))
        else
          @user_data.collect! do |up|
            if (up.login == login )
              if (up.status == UserData.NEW and status == UserData.NEW)
                up.password = data["password"]
                up.sso_provider = data["sso_provider"]
                up.first_name = data["first_name"]
                up.last_name = data["last_name"]
              elsif (up.status == UserData.CHANGED and status == UserData.NEW)
                @@log.debug "Login=#{login} status was CHANGED - leaving CHANGED"
              elsif (up.status == status)
                @@log.debug "Login=#{login} same status - no work done"
              elsif (up.status == UserData.CREATED and status == UserData.NEW)
                # This two fields are change by user_project section - only moving to persistent without object change
                up.admin = data["admin"]
                up.admin_role = data["admin_role"]
                if (Helper.blank?(up.sso_provider) and Helper.blank?(data["sso_provider"]))
                  up.status = UserData.CREATED
                  @@log.debug "Login=#{login} status was CREATED, change is SSO_PROVIDER was not done (both blank) - leaving CREATED"
                elsif (up.sso_provider != data["sso_provider"])
                  up.sso_provider = data["sso_provider"]
                  up.status = UserData.CHANGED
                  @@log.debug "Login=#{login} status was CREATED, change in SSO_PROVIDER was done - changing to CHANGED"
                else
                  up.status = UserData.CREATED
                  @@log.debug "Login=#{login} status was CREATED, change is SSO_PROVIDER was not done - leaving CREATED"
                end
              elsif (up.status == UserData.CHANGED and status == UserData.CREATED)
                up.status = UserData.CREATED
              elsif (up.status == UserData.NEW and status == UserData.CREATED)
                up.uri = data["uri"]
                up.sso_provider = data["sso_provider"]
                up.status = UserData.CREATED
              else
                fail "Unsuported status change - #{up.status} #{status}"
              end
            end
            up
          end
        end
      end




      def change_user_project_status(login,project_pid,status,data)
        user_check = @user_project_data.find{|up| up.project_pid == project_pid and up.login == login }
        if (user_check.nil?)
          @user_project_data.push(UserProjectData.new(status,data))
        else
          @user_project_data.collect! do |up|
            if (up.project_pid == project_pid and up.login == login )
              if (up.status == status)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} same status - no work done"
              elsif (up.status == UserProjectData.TO_DISABLE and status == UserProjectData.OK)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} project-user was TO_DISABLE now it is OK"
                up.status = UserProjectData.OK
              elsif (up.status == UserProjectData.TO_DISABLE and status == UserProjectData.NEW)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} project-user was TO_DISABLE now it is NEW - it is in source file - setting for OK"
                if (up.role != data["role"])
                  up.status = UserProjectData.CHANGED
                  up.role = data["role"]
                else
                  up.status = UserProjectData.OK
                end
              elsif (up.status == UserProjectData.TO_DISABLE and status == UserProjectData.DISABLED)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} project-user was TO_DISABLE now it is DISABLED"
                up.status = UserProjectData.DISABLED
              elsif (up.status == UserProjectData.OK and status == UserProjectData.TO_DISABLE)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} project-user was OK now it is TO_DISABLE"
                up.status = UserProjectData.TO_DISABLE
              elsif (up.status == UserProjectData.NEW and status == UserProjectData.TO_DISABLE)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} project-user was NEW now it is TO_DISABLE - leaving NEW"
                up.status = UserProjectData.NEW
              elsif (up.status == UserProjectData.DISABLED and status == UserProjectData.TO_DISABLE)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} project-user was DISABLED requested status change to TO_DISABLE - leaving in DISABLE"
                up.status = UserProjectData.DISABLED
              elsif (up.status == UserProjectData.DISABLED and status == UserProjectData.NEW)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} project-user was DISABLED requested status change to NEW - setting status to CHANGE "
                up.status = UserProjectData.CHANGED
              elsif (up.status == UserProjectData.OK and status == UserProjectData.CHANGED)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} project-user was OK now it is CHANGED"
                up.status = UserProjectData.CHANGED
                up.role = data["role"]
              elsif (up.status == UserProjectData.CHANGED and status == UserProjectData.NEW)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} project-user was CHANGED, leaving CHANGED"
                up.status = UserProjectData.CHANGED
              elsif (up.status == UserProjectData.CHANGED and status == UserProjectData.OK)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} project was CHANGED now it is OK"
                up.status = UserProjectData.OK
              elsif (up.status == UserProjectData.OK and status == UserProjectData.NEW)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} project-user was OK now it is NEW - leaving OK"
                up.status = UserProjectData.OK
              elsif (up.status == UserProjectData.NEW and status == UserProjectData.OK)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} project-user was NEW now it is OK"
                up.notification_send = data["notification_send"] if !data.nil?
                up.status = UserProjectData.OK
              elsif (up.status == UserProjectData.OK and status == UserProjectData.TO_DISABLE_BY_PROJECT)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} project-user was OK now it is TO_DISABLE_BY_PROJECT"
                up.status = UserProjectData.TO_DISABLE_BY_PROJECT
              elsif (up.status == UserProjectData.CHANGED and status == UserProjectData.TO_DISABLE_BY_PROJECT)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} project-user was CHANGED now it is TO_DISABLE_BY_PROJECT - leaving DISABLED"
                up.status = UserProjectData.DISABLED
              elsif (up.status == UserProjectData.TO_DISABLE_BY_PROJECT and status == UserProjectData.DISABLED)
                @@log.debug "Login=#{login} Project_pid=#{project_pid} project-user was TO_DISABLE_BY_PROJECT now it is DISABLED"
                up.status = UserProjectData.DISABLED
              else
                fail "Unsuported status change - #{up.status} #{status}"
              end
            end
            up
          end
        end
      end




      def merge_user(data)
        user = @user_data.find do |u|
          u.login == data.login
        end
        if (user.nil?)
          @user_data.push(data)
        else
          @user_data.collect! do |d|
            if (d.login == data.login)
              d.admin = data.admin
              d.admin_role = data.admin_role
              d.password = data.password
              d.uri = data.uri if !Helper.blank?(data.uri)
            end
            d
          end
        end
      end

      def merge_user_project(login,user_project_data)
        user = @user_data.find{|u| u.login == login}
        if (!user.nil?)
          user.add_or_update_user_project_mapping(login,user_project_data)
        else
          fail "You are looking for user in user data, but you have not found it. This should not happen"
        end

      end

      def get_projects_by_status(status)
        @project_data.find_all{|d| d.status == status}
      end

      def get_maintenance_by_status(status)
        @maintenance_data.find_all{|d| d.status == status}
      end

      def get_maintenance_by_status_not(status)
        @maintenance_data.find_all{|d| d.status != status}
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
        @user_data.find_all{|e| e.status == status}
      end

      def get_user_by_login(login)
        @user_data.find{|e| e.login == login}
      end


      def get_users_by_admin
        @user_data.find_all{|e| e.admin == true}
      end

      def get_role_uri_by_name(name,pid)
        @@log.info "Looking for #{name} in #{pid}"
        if (@roles.has_key?(name))
          @@log.info "Role URI - #{@roles[name]["uri"]}"
          @roles[name]["uri"].gsub("%PID%",pid)
        else
          @@log.warn "Role #{name} is not valid GoodData role. Setting role to readOnlyUserRole by default"
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
        @project_data.delete_if {|p| p.project_pid == project_pid}
      end

      def delete_etl_by_project_pid(project_pid)
        @etl_data.delete_if {|e| e.project_pid == project_pid }
      end

      def delete_user_project_by_project_pid(project_pid)
        init_user if @user_project_data.nil?
        @user_project_data.delete_if {|up| up.project_pid == project_pid}
      end

    end


  end


end