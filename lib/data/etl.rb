module PowerByHelper

  class Etl


    def initialize()
      load_data_structure()
    end

    def load_data_structure()
      fail "ETL process source directory don't exist" unless File.directory?(Settings.deployment_etl_process["source"])
      Persistent.init_etl
      @@log.info "Persistent storage for etl provisioning initialized"
    end

    def deploy_process()

      Persistent.project_data.each do |p|

        etl = Persistent.get_etl_by_project_pid(p.project_pid)
        if ((etl.nil? or etl.status == EtlData.NEW) and (p.status != ProjectData.DELETED and p.status != ProjectData.DISABLED))
          @@log.info "Deploying process for #{p.project_name} - #{p.project_pid}"
          etl = EtlData.new({"project_pid" => p.project_pid,"status" => EtlData.NEW})
          response = deploy_update_graph(Settings.deployment_etl_process["source"],p.project_name,p.project_pid)
          etl.process_id = response["process"]["links"]["self"].split("/").last
          etl.status = EtlData.PROCESS_CREATED
          Persistent.update_etl(etl)
          @@log.info "Deploy completed"
        end

      end

    end

    def create_schedules()
      schedule_settings = Settings.deployment_etl_schedule
      Persistent.etl_data.each do |etl|
        if (Integer(etl.status) < Integer(EtlData.SCHEDULE_CREATED))
          @@log.info "Creating schedule for #{etl.project_pid}"
          project = Persistent.get_project_by_project_pid(etl.project_pid)
          response = create_update_schedule(schedule_settings,etl.project_pid,etl.process_id,"#{project.ident}")
          schedule_id = response["schedule"]["links"]["self"].split("/").last
          etl.schedule_id = schedule_id
          etl.status = EtlData.SCHEDULE_CREATED
          Persistent.update_etl(etl)
          @@log.info "Schedule created"
        end
      end

    end


    def update_schedules()
      schedule_settings = Settings.deployment_etl_schedule
      Persistent.etl_data.each do |etl|
        if (!etl.is_updated_schedule)
          project = Persistent.get_project_by_project_pid(etl.project_pid)
          response = create_update_schedule(schedule_settings,etl.project_pid,etl.process_id,"#{project.ident}",etl.schedule_id)
          etl.is_updated_schedule = true
          Persistent.update_etl(etl)
        end
      end
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
        Settings.deployment_etl_notifications.each do |notification_settings|
          Persistent.etl_data.each do |etl|
            if (Integer(etl.status) < Integer(EtlData.NOTIFICATION_CREATED))
              @@log.info "Creating notification for #{etl.project_pid}"
              response = create_notification(notification_settings,etl.project_pid,etl.process_id)
              etl.status = EtlData.NOTIFICATION_CREATED
              Persistent.update_etl(etl)
              @@log.info "Notification created #{etl.project_pid}"
            end
          end
        end
      end
    end



    def deploy_update_graph(dir,name,pid, process_id = nil )
      dir = Pathname(dir)

      old_dir = Dir.pwd
      Dir.chdir(dir)
      deploy_name = name
      res = nil
      Tempfile.open("deploy-graph-archive") do |temp|
        Zip::ZipOutputStream.open(temp.path) do |zio|
          Dir.glob("**/*") do |item|
            unless File.directory?(item)
              zio.put_next_entry(item)
              zio.print IO.read(item)
            end
          end
        end

        GoodData.connection.upload(temp.path)
        data = {
            :process => {
                :name => deploy_name,
                :path => "/uploads/#{File.basename(temp.path)}"
            }
        }
        if process_id.nil?
          res = GoodData.post("/gdc/projects/#{pid}/dataload/processes", data)
        else
          res = GoodData.put("/gdc/projects/#{pid}/dataload/processes/#{process_id}", data)
        end
      end
      Dir.chdir(old_dir)
      res
    end

    #Schedule_identification will be automaticaly inserted in MODE param distinguish schedule

    def create_update_schedule(schedule_settings,pid,process_id,project_ident,schedule_id = nil)

      value = nil
      res = nil
      cron = schedule_settings["cron"]
      path = Dir["#{Settings.deployment_etl_process["source"]}**/#{schedule_settings["graph_name"]}"].first
      path = path.gsub(Settings.deployment_etl_process["source"], "")
      graph_name = path

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




    attr_accessor :project_pid,:process_id,:cron,:schedule_id,:status,:is_updated_schedule,:is_updated_notification

    def self.NEW
      0
    end

    def self.PROCESS_CREATED
      1
    end

    def self.SCHEDULE_CREATED
      2
    end

    def self.NOTIFICATION_CREATED
      3
    end

    def initialize(data)
      @project_pid = data["project_pid"]
      @process_id = data["process_id"]
      @schedule_id = data["schedule_id"]
      @cron = data["cron"]
      @status = data["status"]
      @is_updated_schedule = data["is_updated_schedule"] || true
      @is_updated_notification = data["is_updated_notification"] || true
    end



    def self.header
      ["project_pid","process_id","schedule_id","status","is_updated_schedule","is_updated_notification"]
    end

    def to_a
      [@project_pid,@process_id,@schedule_id,@status,@is_updated_schedule,@is_updated_notification]
    end


    def ident
      "#{@project_pid}-#{@process_id}-#{@schedule_id} "
    end




  end




end
