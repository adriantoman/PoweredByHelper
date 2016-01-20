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

  class Maintenance

    BUFFER_SIZE = 3

    def initialize()
      load_data_structure()
    end

    def load_data_structure()
      fail "ETL process source directory don't exist" unless File.directory?(Settings.deployment_etl_process["source"])
      Persistent.init_project
      Persistent.init_maintenance
      @@log.info "Persistent storage for maintenance initialized"
    end

    def executed_maql(maql_file)
      fail "The maql file doesn't exists" if !File.exist?(maql_file)
      maql = File.read(maql_file)

      Persistent.maintenance_data.each do |m|
        fail "I have found out, that there is unfinished task from different maintanence task" if MaintenanceData.MAQL_TASKS.find{|t| t == m.status}.nil?
      end

      #Test if some maintenance tasks are unfinished
      unfinished_tasks = Persistent.get_maintenance_by_status_not(MaintenanceData.OK)



      if (unfinished_tasks.empty?)
        @@log.info "Loading all project for maintenance"
        Persistent.maintenance_data.clear
        Persistent.project_data.each do |p|
          Persistent.change_maintenance_status(p.project_pid,MaintenanceData.PROCESSING_MAQL_SCHEDULED,{"project_pid" => p.project_pid,"status" => MaintenanceData.PROCESSING_MAQL_SCHEDULED})
        end
      else
        @@log.info "There are some unfinished tasks from previous run, continuing"
        error_tasks = Persistent.get_maintenance_by_status(MaintenanceData.ERROR)
        if (!error_tasks.empty?)
          @@log.info "I have found out error task(s), retrying"
          error_tasks.each do |p|
            Persistent.change_maintenance_status(p.project_pid,MaintenanceData.PROCESSING_MAQL_SCHEDULED,{"project_pid" => p.project_pid,"status" => MaintenanceData.PROCESSING_MAQL_SCHEDULED})
          end
        end
      end
      maintenance = Persistent.maintenance_data
      done = false
      buffer_count = 0
      while (!done)
        maintenance.each do |m|
          if (buffer_count < BUFFER_SIZE and m.status == MaintenanceData.PROCESSING_MAQL_SCHEDULED)
            result = MaintenanceHelper.execute_maql(m,maql)
            if (!result.nil?)
              task_id = result["entries"].first["link"].match(/.*\/tasks\/(.*)\/status/)[1]
              Persistent.change_maintenance_status(m.project_pid,MaintenanceData.PROCESSING_MAQL_TASK_CREATED,{"task_id" => task_id})
              Persistent.store_maintenance
              buffer_count += 1
              @@log.info "Processing task for #{m.project_pid} successfully send to Gooddata"
            else
              Persistent.change_maintenance_status(m.project_pid,MaintenanceData.ERROR,nil)
              Persistent.store_maintenance
              @@log.info "Seding task to GD for #{m.project_pid} has failed"
            end
          end
        end
        maintenance.each do |m|
          if (m.status == MaintenanceData.PROCESSING_MAQL_TASK_CREATED)
            status = MaintenanceHelper.check_task_status(m)
            if (status == "OK")
              Persistent.change_maintenance_status(m.project_pid,MaintenanceData.OK,{"task_id" => nil})
              Persistent.store_maintenance
              buffer_count -= 1
              @@log.info "Task for #{m.project_pid} has finished OK"
            elsif (status == "ERROR")
              Persistent.change_maintenance_status(m.project_pid,MaintenanceData.ERROR,nil)
              Persistent.store_maintenance
              buffer_count -= 1
              @@log.info "Task for #{m.project_pid} has finished ERROR"
            end
          end
        end
        done = true if maintenance.count{|m| m.status == MaintenanceData.PROCESSING_MAQL_SCHEDULED or m.status == MaintenanceData.PROCESSING_MAQL_TASK_CREATED} == 0
      end
    end

    def execute_partial_metadata(export_token)
      fail "Token reference is empty" if export_token == "" or export_token.nil?

      Persistent.maintenance_data.each do |m|
        fail "I have found out, that there is unfinished task from different maintanence task" if MaintenanceData.PARTIAL_TASKS.find{|t| t == m.status}.nil?
      end
      #Test if some maintenance tasks are unfinished
      unfinished_tasks = Persistent.get_maintenance_by_status_not(MaintenanceData.OK)

      if (unfinished_tasks.empty?)
        @@log.info "Loading all project for maintenance"
        Persistent.maintenance_data.clear
        Persistent.project_data.each do |p|
          Persistent.change_maintenance_status(p.project_pid,MaintenanceData.PROCESSING_PARTIAL_SCHEDULED,{"project_pid" => p.project_pid,"status" => MaintenanceData.PROCESSING_PARTIAL_SCHEDULED})
        end
      else
        @@log.info "There are some unfinished tasks from previous run, continuing"
        error_tasks = Persistent.get_maintenance_by_status(MaintenanceData.ERROR)
        if (!error_tasks.empty?)
          @@log.info "I have found out error task(s), retrying"
          error_tasks.each do |p|
            Persistent.change_maintenance_status(p.project_pid,MaintenanceData.PROCESSING_PARTIAL_SCHEDULED,{"project_pid" => p.project_pid,"status" => MaintenanceData.PROCESSING_PARTIAL_SCHEDULED})
          end
        end
      end
      maintenance = Persistent.maintenance_data
      done = false
      buffer_count = 0
      while (!done)
        maintenance.each do |m|
          if (buffer_count < BUFFER_SIZE and m.status == MaintenanceData.PROCESSING_PARTIAL_SCHEDULED)
            result = MaintenanceHelper.execute_partial_import(m,export_token)
            if (!result.nil?)
              task_id = result["uri"].match(/.*\/tasks\/(.*)\/status/)[1]
              Persistent.change_maintenance_status(m.project_pid,MaintenanceData.PROCESSING_PARTIAL_TASK_CREATED,{"task_id" => task_id})
              Persistent.store_maintenance
              @@log.info "Processing task for #{m.project_pid} successfully send to Gooddata"
              buffer_count += 1
            else
              Persistent.change_maintenance_status(m.project_pid,MaintenanceData.ERROR,nil)
              Persistent.store_maintenance
              @@log.info "Processing task for #{m.project_pid} has failed on error"
            end
          end
        end
        maintenance.each do |m|
          if (m.status == MaintenanceData.PROCESSING_PARTIAL_TASK_CREATED)
            @@log.info "Checking task for #{m.project_pid} status"
            status = MaintenanceHelper.check_task_status(m)
            if (status == "OK")
              @@log.info "Task for #{m.project_pid} has finished OK"
              Persistent.change_maintenance_status(m.project_pid,MaintenanceData.OK,{"task_id" => nil})
              Persistent.store_maintenance
              buffer_count -= 1
            elsif (status == "ERROR")
              @@log.info "Task for #{m.project_pid} has finished ERROR"
              Persistent.change_maintenance_status(m.project_pid,MaintenanceData.ERROR,{})
              Persistent.store_maintenance
              buffer_count -= 1
            else
              @@log.info "Task for #{m.project_pid} didn't finished yet"
            end
          end
        end
        done = true if maintenance.count{|m| m.status == MaintenanceData.PROCESSING_PARTIAL_SCHEDULED or m.status == MaintenanceData.PROCESSING_PARTIAL_TASK_CREATED} == 0
      end
    end


    def create_update_key_value(key,value)
      fail "Key is empty" if key.nil? or key == ""

      Persistent.maintenance_data.clear
      Persistent.project_data.each do |p|
        Persistent.change_maintenance_status(p.project_pid,MaintenanceData.START,{"project_pid" => p.project_pid,"status" => MaintenanceData.START})
      end

      maintenance = Persistent.maintenance_data
      maintenance.each do |m|
        result = MaintenanceHelper.create_update_value(m,key,value)
        if (!result.nil?)
          Persistent.change_maintenance_status(m.project_pid,MaintenanceData.OK,nil)
          Persistent.store_maintenance
          @@log.info "Value successfully changed for pid #{m.project_pid}"
        else
          Persistent.change_maintenance_status(m.project_pid,MaintenanceData.ERROR,nil)
          Persistent.store_maintenance
          @@log.info "Value change for #{m.project_pid} has failed on error"
        end
      end
    end



  end

  class MaintenanceData




    attr_accessor :project_pid,:status,:task_id

    def self.MAQL_TASKS
      [MaintenanceData.OK,MaintenanceData.ERROR,MaintenanceData.PROCESSING_MAQL_TASK_CREATED,MaintenanceData.PROCESSING_MAQL_SCHEDULED]
    end

    def self.PARTIAL_TASKS
      [MaintenanceData.OK,MaintenanceData.ERROR,MaintenanceData.PROCESSING_PARTIAL_SCHEDULED,MaintenanceData.PROCESSING_PARTIAL_TASK_CREATED]
    end

    def self.STORAGE_TASKS
      [MaintenanceData.OK,MaintenanceData.ERROR]
    end


    def self.START
      "START"
    end

    def self.OK
      "OK"
    end

    def self.ERROR
      "ERROR"
    end


    def self.PROCESSING_MAQL_SCHEDULED
      "PROCESSING_MAQL_SCHEDULED"
    end

    def self.PROCESSING_MAQL_TASK_CREATED
      "PROCESSING_MAQL_TASK_CREATED"
    end


    def self.PROCESSING_PARTIAL_SCHEDULED
      "PROCESSING_PARTIAL_SCHEDULED"
    end

    def self.PROCESSING_PARTIAL_TASK_CREATED
      "PROCESSING_PARTIAL_TASK_CREATED"
    end


    def initialize(data)
      @project_pid = data["project_pid"]
      @status = data["status"]
      @task_id = data["task_id"]
    end

    def self.header
      ["project_pid","status","task_id"]
    end

    def to_a
      [@project_pid,@status,@task_id]
    end




  end




end
