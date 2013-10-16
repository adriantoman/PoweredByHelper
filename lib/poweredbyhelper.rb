require 'json'
require 'gooddata'

require 'fastercsv'
require 'fileutils'

%w(settings helper persistent userhelper).each {|a| require "#{a}"}
%w(project etl user).each {|a| require "data/#{a}"}

module PowerByHelper

  class Pwb

    def initialize(config_file,test_mode)
      @@test_mode = test_mode || false
      File.open( config_file, "r" ) do |f|
        json = JSON.load( f )
        Settings.load(json)
      end
    end


    def gooddata_login
      login = Settings.connection["login"]
      password = Settings.connection["password"]
      server = Settings.connection_server
      fail "Please put Gooddata Login and Password into the config file" if Helper.blank?(login) or Helper.blank?(password)
      GoodData.logger = @@log
      GoodData.connect(login,password,server,{:webdav_server => Settings.connection_webdav})
    end

    def init_persistent_storage
      @projects = Project.new() if (!Settings.deployment_project.nil? and !Settings.deployment_project.empty?)
      @etl = Etl.new() if (!Settings.deployment_etl.nil? and !Settings.deployment_etl.empty?)
    end

    def init_user_storage
      @user = User.new() if (!Settings.deployment_user.nil? and !Settings.deployment_user.empty?)
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
        @user.invite_users
        @user.add_users
        @user.disable_users
        @user.update_users
      end
      #end
    end


    def update_schedules()
      @@log.info "Starting schedule update"
      Persistent.reset_schedule_update
      Helper.retryable do
        @etl.update_schedules
      end
    end





    def delete_all_projects(force)
      $log.info "Deleting project - dry run (to normal run specify force parameter)" if force
      Persistent.project_data.each do |project|
        if (!project.nil? and !project.project_pid.nil?)
          $log.info "Deleting project #{project.project_pid}"
          project = GoodData::Project[project.project_pid]
          project.delete if force
        end
      end
    end







  end


end