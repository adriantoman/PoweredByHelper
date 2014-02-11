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

  class Etl


    def initialize()
      load_data_structure()
    end

    def load_data_structure()
      fail "ETL process source directory don't exist" unless File.directory?(Settings.deployment_etl_process["source"])

      Persistent.init_etl

      schedule_settings = Settings.deployment_etl_schedule
      if (!schedule_settings.is_a?(Array))
        schedule_settings = [schedule_settings]
      end

      # check if ident parameter is set up in case of multiple schedules
      if (schedule_settings.count > 1)
        schedule_settings.each do |setting|
          fail "You want to use multiple schedules and there is no ident parameter for one of the schedules \n #{setting}" if setting["ident"].nil?
        end
      end

      value = schedule_settings.group_by { |e| e["ident"] }.select { |k, v| v.size > 1 }.map(&:first)
      fail "You have multiple schedules with same ID" if !value.empty?
      temp = 1
      Persistent.project_data.each do |p|
        if  (p.status != ProjectData.DELETED and p.status != ProjectData.DISABLED)
          if p.project_pid.nil?
            project_pid = temp
          else
            project_pid = p.project_pid
          end

          Persistent.change_etl_status(project_pid,EtlData.NEW,{"project_pid" => project_pid,"status" => EtlData.NEW})

          schedule_settings.each do |schedule_settings|
            schedule_ident = schedule_settings["ident"].nil? ? "1" : schedule_settings["ident"]
            data = {
                  "project_pid" => project_pid,
                  "ident" => schedule_ident,
                  "status" => ScheduleData.NEW
            }
            Persistent.change_schedule_status(project_pid,schedule_ident,ScheduleData.NEW,data)
          end
        end
        temp += 1
      end
      @@log.info "Persistent storage for etl provisioning initialized"
    end

    def deploy_process()
      Persistent.etl_data.each do |etl|
        if (etl.status == EtlData.NEW)
          project = Persistent.get_project_by_project_pid(etl.project_pid)
          @@log.info "Deploying process for #{project.project_name} - #{etl.project_pid}"
          response = deploy_update_graph(Settings.deployment_etl_process["source"],project.project_name,etl.project_pid)
          process_id = response["process"]["links"]["self"].split("/").last
          Persistent.change_etl_status(etl.project_pid,EtlData.PROCESS_CREATED,{"process_id" => process_id})
          Persistent.store_etl
          @@log.info "Deploy completed"
        end
      end
    end

    def create_schedules()

      #get_etl_by_project_pid
      Persistent.schedule_data.each do |schedule|
        if (schedule.status == ScheduleData.NEW)
          @@log.info "Creating schedule for project_pid: #{schedule.project_pid} ident: #{schedule.ident}"
          project = Persistent.get_project_by_project_pid(schedule.project_pid)
          process = Persistent.get_etl_by_project_pid(schedule.project_pid)
          schedule_settings = Settings.deployment_etl_schedule
          if (schedule_settings.is_a?(Array))
            settings = schedule_settings.find{|s| s["ident"] == schedule.ident or (s["ident"].nil? and schedule_settings.count == 1 and schedule.ident == "1")}
          else
            settings = schedule_settings
          end
          response = create_update_schedule(settings,schedule.project_pid,process.process_id,"#{project.ident}")
          schedule_id = response["schedule"]["links"]["self"].split("/").last
          Persistent.change_schedule_status(schedule.project_pid,schedule.ident,ScheduleData.SCHEDULE_CREATED,{"schedule_id" => schedule_id})
          Persistent.store_schedules
          @@log.info "Schedule created"
        end
      end

    end


    def update_schedules()
      schedule_settings = Settings.deployment_etl_schedule
      if (!schedule_settings.is_a?(Array))
        schedule_settings = [schedule_settings]
      end



      # check if ident parameter is set up in case of multiple schedules
      if (schedule_settings.count > 1)
        schedule_settings.each do |setting|
          fail "You want to use multiple schedules and there is no ident parameter for one of the schedules \n #{setting}" if setting["ident"].nil?
        end
      end

      value = schedule_settings.group_by { |e| e["ident"] }.select { |k, v| v.size > 1 }.map(&:first)
      fail "You have multiple schedules with same ID" if !value.empty?

      # Update already created schedules
      Persistent.schedule_data.each do |schedule|
        if (!schedule.is_updated_schedule)
          project = Persistent.get_project_by_project_pid(schedule.project_pid)
          process = Persistent.get_etl_by_project_pid(schedule.project_pid)
          settings = schedule_settings.find{|s| s["ident"] == schedule.ident or (s["ident"].nil? and schedule_settings.count == 1 and schedule.ident == "1")}

          if (settings.nil?)
            # The setting for this schedule was remove from config file, schedule should be disabled
            begin
              @@log.info "Disabling schedule #{schedule.schedule_id} ident:#{schedule.ident} for project #{schedule.project_pid}"
              disable_schedule(schedule.project_pid,schedule.schedule_id)
              Persistent.schedule_data.delete_if{|d| d.schedule_id == schedule.schedule_id}
              @@log.info "Disable successful"
            rescue RestClient::BadRequest => e
              response = JSON.load(e.response)
              @@log.warn "Schedule #{schedule.project_pid} disable failed. Reason: #{response["error"]["message"]}"
            rescue RestClient::InternalServerError => e
              response = JSON.load(e.response)
              @@log.warn "Schedule #{schedule.project_pid} disable failed. Reason: #{response["error"]["message"]}"
            end
          else
            # The setting for this schedule is in config file, schedule should be updated
            begin
              @@log.info "Updating schedule: #{schedule.schedule_id} ident:#{schedule.ident} for project #{schedule.project_pid}"
              response = create_update_schedule(settings,schedule.project_pid,process.process_id,"#{project.ident}",schedule.schedule_id)
              schedule_id = response["schedule"]["links"]["self"].split("/").last
              Persistent.change_schedule_status(schedule.project_pid,schedule.ident,ScheduleData.SCHEDULE_CREATED,{"schedule_id" => schedule_id,"is_updated_schedule" => true})
              @@log.info "Update successful"
            rescue RestClient::BadRequest => e
              response = JSON.load(e.response)
              @@log.warn "Schedule #{schedule.project_pid} could not be updated. Reason: #{response["error"]["message"]}"
            rescue RestClient::InternalServerError => e
              response = JSON.load(e.response)
              @@log.warn "Schedule #{schedule.project_pid} could not be updated. Reason: #{response["error"]["message"]}"
            end
          end
          Persistent.store_schedules
        end
      end

      # Schedules which need to be disabled


    end

    def update_processes()
      Persistent.project_data.each do |p|
        if (p.status != ProjectData.DELETED)
          etl = Persistent.etl_data.find{|etl| etl.project_pid == p.project_pid}
          if (!etl.nil?)
            @@log.info "Redeploying project #{p.project_name} - #{p.project_pid} and process #{etl.process_id}"
            deploy_update_graph(Settings.deployment_etl_process["source"],p.project_name,p.project_pid,etl.process_id)
          end
        end
      end
    end


    def create_notifications
      if (!Settings.deployment_etl_notifications.nil? && Settings.deployment_etl_notifications.count > 0)
          Persistent.etl_data.each do |etl|
            if ( etl.status == EtlData.PROCESS_CREATED)
              count = 1
              Settings.deployment_etl_notifications.each do |notification_settings|
                @@log.info "Creating notification number #{count} for #{etl.project_pid}"
                response = create_notification(notification_settings,etl.project_pid,etl.process_id)
                @@log.info "Notification number #{count} created #{etl.project_pid}"
                count += 1
              end
              Persistent.change_etl_status(etl.project_pid,EtlData.NOTIFICATION_CREATED,{})
              Persistent.store_etl
            end

        end
      end
    end



    def deploy_update_graph(dir,name,pid, process_id = nil )
      #dir = Pathname(dir)

      #old_dir = Dir.pwd
      #Dir.chdir(dir)
      deploy_name = name
      res = nil

      FileUtils.rm_f("deploy-process.zip") if File.exists?("deploy-process.zip")

      processed_files = []
      Zip::ZipFile.open("deploy-process.zip", Zip::ZipFile::CREATE) do |zipfile|
        Dir[File.join(dir, '**','**')].each do |file|
          temp = processed_files.find{|f| f == file}
          if (temp.nil?)
            unless File.directory?(file)
              zipfile.add(file.sub(dir,''), file)
              processed_files.push(file)
            end
          end
        end
      end

      GoodData.connection.upload("deploy-process.zip")
      data = {
          :process => {
              :name => deploy_name,
              :path => "/uploads/deploy-process.zip"
          }
      }
      if process_id.nil?
        res = GoodData.post("/gdc/projects/#{pid}/dataload/processes", data)
      else
        res = GoodData.put("/gdc/projects/#{pid}/dataload/processes/#{process_id}", data)
      end
      FileUtils.rm_f("deploy-process.zip")
      res
    end

    #Schedule_identification will be automaticaly inserted in MODE param distinguish schedule

    def disable_schedule(project_pid,schedule_id)
      response = GoodData.get("/gdc/projects/#{project_pid}/schedules/#{schedule_id}")
      response["schedule"]["state"] = "DISABLED"
      response["schedule"].reject!{|s| s == "nextExecutionTime" or s == "consecutiveFailedExecutionCount" or s == "links"}
      GoodData.put("/gdc/projects/#{project_pid}/schedules/#{schedule_id}", response)
    end


    def create_update_schedule(schedule_settings,pid,process_id,project_ident,schedule_id = nil)
      value = nil
      res = nil
      cron = schedule_settings["cron"]
      path = Dir["#{Settings.deployment_etl_process["source"]}**/#{schedule_settings["graph_name"]}"].first
      path = path.gsub(Settings.deployment_etl_process["source"], "")
      graph_name = path

      cron = Helper.replace_custom_parameters(project_ident,cron)

      data = {
          "schedule" => {
            "type" => "MSETL",
            "timezone" => "UTC",
            "cron" => "#{cron}",
            "params"=> {
              "PROCESS_ID" => "#{process_id}",
              "GRAPH" => "#{graph_name}"
            },
            "hiddenParams" => {
            }
        }
      }

      if (!schedule_settings["reschedule"].nil? and schedule_settings["reschedule"] !=  "" )
        if (schedule_settings["reschedule"].instance_of? Fixnum )
          data["schedule"].merge!({"reschedule" => schedule_settings["reschedule"] })
        else
          @@log.warn "The reschedule setting is not number, please change it to number - ignoring the reschedule setting"
        end
      end


      #add parameters
      schedule_settings["parameters"].each do |parameters|
        value_param = parameters["value"]
        value_param = value_param.gsub("%ID%",project_ident)
        value_param = Helper.replace_custom_parameters(project_ident,value_param)
        json = { parameters["name"] => value_param }
        data["schedule"]["params"].merge!(json)
      end

      # add secure parameters
      schedule_settings["secure_parameters"].each do |parameters|
        value_param = parameters["value"]
        value_param = value_param.gsub("%ID%",project_ident)
        value_param = Helper.replace_custom_parameters(project_ident,value_param)
        json = {parameters["name"] => value_param}
        data["schedule"]["hiddenParams"].merge!(json)
      end
      if schedule_id.nil?
        res = GoodData.post("/gdc/projects/#{pid}/schedules", data)
      else
        res = GoodData.put("/gdc/projects/#{pid}/schedules/#{schedule_id}", data)
      end
      res
    end


    def create_notification(notification_setting,pid,process_id)

      mapping = {
          "error" => "dataload.process.finish.error",
          "success" => "dataload.process.finish.ok",
          "schedule" => "dataload.process.schedule",
          "start" => "dataload.process.start"
      }

      data = {
          "notificationRule" => {
              "email" => notification_setting["email"],
              "subject" => notification_setting["subject"],
              "body" => notification_setting["message"],
              "events" => [mapping[notification_setting["type"]]]
          }
      }

      GoodData.post("gdc/projects/#{pid}/dataload/processes/#{process_id}/notificationRules",data)
    end


  end





  class EtlData

    attr_accessor :project_pid,:process_id,:status,:is_updated_notification

    def self.NEW
      "0"
    end

    def self.PROCESS_CREATED
      "1"
    end

    def self.NOTIFICATION_CREATED
      "2"
    end

    def initialize(data)
      @project_pid = data["project_pid"]
      @process_id = data["process_id"]
      @status = data["status"]
      @is_updated_notification = data["is_updated_notification"] || true
    end

    def self.header
      ["project_pid","process_id","status","is_updated_notification"]
    end

    def to_a
      [@project_pid,@process_id,@status,@is_updated_notification]
    end


    def ident
      "#{@project_pid}-#{@process_id}-#{@schedule_id} "
    end




  end


  class ScheduleData

    attr_accessor :project_pid,:ident,:schedule_id,:status,:cron,:is_updated_schedule

    def self.NEW
      "0"
    end

    def self.SCHEDULE_CREATED
      "1"
    end

    def initialize(data)
      @project_pid = data["project_pid"]
      @ident = data["ident"]
      @schedule_id = data["schedule_id"]
      @cron = data["cron"]
      @status = data["status"]
      @is_updated_schedule = data["is_updated_schedule"] || true
    end

    def self.header
      ["project_pid","ident","schedule_id","status","is_updated_schedule"]
    end

    def to_a
      [@project_pid,@ident,@schedule_id,@status,@is_updated_schedule]
    end



  end




end
