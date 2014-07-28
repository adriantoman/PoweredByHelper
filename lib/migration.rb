# encoding: UTF-8

module PowerByHelper


  # This class will do necessery changes to data strcuture
  class Migration


    # Migration from version v0.1 to v0.2 - schedule and process change
    # Change of etl.csv - divide to etl.csv and schedule.csv
    def migrationA

      start_migration = false

      if File.exists?(Settings.storage_etl_source)
        FasterCSV.foreach(Settings.storage_etl_source, :headers => true,:quote_char => '"') do |csv_obj|
          if (!csv_obj["schedule_id"].nil? and !csv_obj["is_updated_schedule"].nil? and !csv_obj["is_updated_notification"].nil?)
            start_migration = true
            break
          else
            break
          end
        end
      end

      if (start_migration)

        etl_source_path = Settings.storage_etl_source
        etl_backup_path = Settings.storage_etl_source.gsub(".csv","_backup.csv")
        schedule_path = Settings.storage_schedules_source

        @@log.info "Migration from v0.1 to v0.2 is needed - STARTING"
        #Lets backup ETL file
        FileUtils.copy(etl_source_path,etl_backup_path)

        values = []
        FasterCSV.foreach(Settings.storage_etl_source, :headers => true,:quote_char => '"') do |csv_obj|
          values.push(csv_obj)
        end

        FasterCSV.open(Settings.storage_etl_source, 'w',:quote_char => '"') do |csv|
          csv << ["project_pid","process_id","status","is_updated_notification"]
          values.each do |d|
            new_status = "1"
            if d["status"] == "0"
              new_status = "0"
            elsif d["status"] == "1" or d["status"] == "2"
              new_status = "1"
            else
              new_status = "2"
            end
            csv << [d["project_pid"],d["process_id"],new_status,d["is_updated_notification"]]
          end
        end

        FasterCSV.open(Settings.storage_schedules_source, 'w',:quote_char => '"') do |csv|
          csv << ["project_pid","ident","schedule_id","status","is_updated_schedule"]
          values.each do |d|
            new_status = "0"
            if d["status"] == "0" or d["status"] == "1"
              new_status = "0"
            else
              new_status = "1"
            end
            csv << [d["project_pid"],"1",d["schedule_id"],new_status,d["is_updated_schedule"]]
          end
        end

        @@log.info "Migration from v0.1 to v0.2 sucessfully FINISHED"
      end
    end


    def migrationB
      start_migration = false

      if File.exists?(Settings.storage_user_project_source)
        start_migration = true
      end

      if (start_migration)
        @@log.info "Starting migration of user_project file from v0.3.13 to v0.4.0 "

        project_user_file = {}

        FasterCSV.foreach(Settings.storage_user_project_source, :headers => true,:quote_char => '"') do |csv_obj|
          if (!project_user_file.include?(csv_obj["project_pid"]))
            project_user_file[csv_obj["project_pid"]] = {}
          end
          project_user_file[csv_obj["project_pid"]][csv_obj["login"]] = csv_obj
        end

        # Match only folder from path
        filename = Settings.storage_user_project_source.match(/(.*\/)([^\/]+$)/)[2]
        FileUtils.mkdir_p(Settings.storage_user_project_directory)

        project_user_file.each_pair do |k,v|
          FasterCSV.open("#{Settings.storage_user_project_directory}user_project_#{k}.csv", 'w',:quote_char => '"') do |csv|
            csv << UserProjectData.header
            v.each_value do |line|
                csv << line
            end
          end
        end
        FileUtils.mkdir_p("backup/")
        FileUtils.move(Settings.storage_user_project_source,"backup/#{filename}")
        @@log.info "Migration from of user_project file v0.3.13 to v0.4.0 finished. The user_project file is backup in backup folder"
      end
    end


    def migrationC
      start_migration = false

      if File.exists?(Settings.storage_muf_source)
        start_migration = true
      end

      if (start_migration)
        @@log.info "Starting migration of muf file from v0.3.13 to v0.4.0"

        muf_projects = []


        $/="\n\n"
        File.open(Settings.storage_muf_source, "r").each do |object|
          muf_projects << YAML::load(object)
        end
        # Match only folder from path
        filename = Settings.storage_muf_source.match(/(.*\/)([^\/]+$)/)[2]
        FileUtils.mkdir_p(Settings.storage_muf_directory)
        muf_projects.each do |project|
          File.open("#{Settings.storage_muf_directory}muf_#{project.pid}.yaml", "w") do |file|
            file.puts YAML::dump(project)
            file.puts ""
          end
        end

        FileUtils.mkdir_p("backup/")
        FileUtils.move(Settings.storage_muf_source,"backup/#{filename}")
        @@log.info "Migration from of muf file v0.3.13 to v0.4.0 finished. The user_project file is backup in backup folder"
      end
    end





  end



end
