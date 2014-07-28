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


require 'json'
require 'gooddata'

require 'fastercsv'
require 'fileutils'
require 'state_machine'
require 'yaml'

%w(settings helper persistent userhelper maintenancehelper migration).each {|a| require "#{a}"}
%w(project etl user maintenance).each {|a| require "data/#{a}"}
%w(muf_collection muf muf_project muf_login).each {|a| require "muf/#{a}"}
require "validation"

module PowerByHelper

  class Pwb

    def initialize(config_file,test_mode)
      @@test_mode = test_mode || false
      File.open( config_file, "r" ) do |f|
        json = JSON.load( f )
        Settings.load(json)
      end

      #Global mail setting - for notification about fail
      if (!Settings.monitoring.nil?)
        $monitoring_mail_target = Settings.monitoring_to
        $monitoring_mail_source = Settings.monitoring_from
      end
    end

    def create_backup
      if (!Settings.backup.nil?)
        MaintenanceHelper.create_backup(Settings.backup_folder,Settings.backup_filename)
      end
    end


    def gooddata_login(debug = false)
      login = Settings.connection["login"]
      password = Settings.connection["password"]
      server = Settings.connection_server
      fail "Please put Gooddata Login and Password into the config file" if Helper.blank?(login) or Helper.blank?(password)
      #GoodData.logger = @@log
      #GoodData.logger.level = Logger::DEBUG if debug
      GoodData.connect(login,password,server,{:webdav_server => Settings.connection_webdav,:headers => {"X-GDC-CC-PRIORITY-MODE" => 'NORMAL'}})
    end

    def check_directories_on_webdav
      Helper.check_directories_on_webdav()
    end


    def init_persistent_storage
      @projects = Project.new() if (!Settings.deployment_project.nil? and !Settings.deployment_project.empty?)
    end

    def init_etl_persistent_storage
      @etl = Etl.new() if (!Settings.deployment_etl.nil? and !Settings.deployment_etl.empty?)
    end

    def init_maintenance_storage
      @maintenance = Maintenance.new()
    end


    def init_user_storage
      @user = User.new()  if (!Settings.deployment_user.nil? and !Settings.deployment_user.empty?)
    end

    def init_muf_storage
      @muf = MufCollection.new() if (!Settings.deployment_mufs.nil?)
    end




    def project_provisioning
      @@log.info "Project persistent storage not initialized - skipping project provisioning" if @projects.nil?
      #Helper.retryable do
        @projects.create_projects
        @projects.handle_projects_disable
      #end
    end

    def etl_provisioning
      @@log.info "Etl persistent storage not initialized - skipping etl provisioning" if @etl.nil?
      #Helper.retryable do
      if (!@etl.nil?)
        @etl.deploy_process
        @etl.create_schedules
        @etl.create_notifications
      end
    end

    def user_synchronization
      #@@log.info "Users persistent storage not initialized - skipping user provisioning" if @user.nil?
      #Helper.retryable do
      init_user_storage
      if (!@user.nil?)
        @user.create_new_users
        @user.change_users
        init_muf_storage
        if (!@muf.nil?)
          @muf.compare
        end
        @user.manage_user_project(@muf)
      end
      #end
    end


    def update_schedules()
      @@log.info "Starting schedule update"
      Persistent.reset_schedule_update
      #Helper.retryable do
        @etl.update_schedules
      #end
    end

    def update_processes()
      @@log.info "Starting process update"
      Helper.retryable do
        @etl.update_processes
      end
    end

    def execute_maql(maql_file)
      @@log.info "Starting maql execution"
      #Helper.retryable do
        @maintenance.executed_maql(maql_file)
      #end
      @@log.info "Maql execution finished"
    end


    def create_update_key_value(key,value)
      @@log.info "Starting key/value update"
      @maintenance.create_update_key_value(key,value)
      @@log.info "Key/value update finished"
    end




    def execute_partial_metadata(token)
      @@log.info "Starting partial metadata execution"
      @maintenance.execute_partial_metadata(token)
      @@log.info "Partial metadata export execution finished"
    end

    def execute_muf_sychronization
      init_muf_storage
      if (!@muf.nil?)
        @muf.compare
        @muf.work
      end
    end


    def execute_muf_compare
      move_remote_mufs_files
      init_muf_storage
      if (!@muf.nil?)
        @muf.compare
      end
    end

    def move_remote_project_files
       if (Settings.deployment_project_data_type == "webdav" and !Settings.deployment_project_data_move_after_processing.nil?)
         filename = Settings.deployment_project_data_file_name.split("/").last
         @@log.info "If exists moving file #{"processing/" + filename} to #{Settings.deployment_project_data_move_after_processing}"
         Helper.move_file_to_other_folder("processing/" + filename,Settings.deployment_project_data_move_after_processing)
       end
    end

    def move_remote_user_files
      if (Settings.deployment_user_creation_type == "webdav" and !Settings.deployment_user_creation_move_after_processing.nil?)
        filename = Settings.deployment_user_creation["source"].split("/").last
        @@log.info "If exists moving file #{"processing/" + filename} to #{Settings.deployment_user_creation_move_after_processing}"
        Helper.move_file_to_other_folder("processing/" + filename,Settings.deployment_user_creation_move_after_processing)
      end

      if (Settings.deployment_user_project_synchronization_type == "webdav" and !Settings.deployment_user_project_synchronization_move_after_processing.nil?)
        filename = Settings.deployment_user_project_synchronization["source"].split("/").last
        @@log.info "If exists moving file #{"processing/" + filename} to #{Settings.deployment_user_project_synchronization_move_after_processing}"
        Helper.move_file_to_other_folder("processing/" + filename,Settings.deployment_user_project_synchronization_move_after_processing)
      end
    end

    def move_remote_mufs_files
      if (Settings.deployment_mufs_type == "webdav" and !Settings.deployment_mufs_webdav_folder_target.nil?)
        Helper.move_all_files_to_other_folder(Settings.deployment_mufs_remote_dir + Settings.deployment_mufs_file_pattern,Settings.deployment_mufs_webdav_folder_target)
      end
    end




    def delete_all_projects(force)
      @@log.info "Deleting project - dry run (to normal run specify force parameter)" if !force
      project_data_copy = Persistent.project_data.clone

      project_data_copy.each do |project|
        if (!project.nil? and !project.project_pid.nil?)
          @@log.info "Deleting project #{project.project_pid} #{ force ? "FORCED" : "DRY RUN"}"
          project_gd = GoodData::Project[project.project_pid]
          if force
            project_gd.delete
            Persistent.delete_user_project_by_project_pid(project.project_pid)
            Persistent.delete_etl_by_project_pid(project.project_pid)
            Persistent.delete_schedule_by_project_pid(project.project_pid)
            Persistent.delete_project_by_project_pid(project.project_pid)
          end
        end
      end
      if (force)
        Persistent.store_project
        Persistent.store_etl
        Persistent.store_schedules
        #Persistent.store_user_project
      end
    end

    def migration()
      @@log.info "Checking if migration is needed"
      @migration = Migration.new
      @migration.migrationA()
      @migration.migrationB()
      @migration.migrationC()
    end


    def run_custom_code(code)
      eval(code)
    end


    def test
      Helper.check_directories_on_webdav()
    end



  end


end