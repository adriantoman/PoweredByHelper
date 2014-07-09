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

    end




  end



end
