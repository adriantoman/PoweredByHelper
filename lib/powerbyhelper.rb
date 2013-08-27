require 'json'
require 'gooddata'

require 'fastercsv'
require "awesome_print"
require 'fileutils'


%w(settings helper persistent).each {|a| require "lib/#{a}"}
%w(project etl user).each {|a| require "lib/data/#{a}"}

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
      server = Settings.connection["server"] || "https://na1.secure.gooddata.com/"
      fail "Please put Gooddata Login and Password into the config file" if Helper.blank?(login) or Helper.blank?(password)
      GoodData.logger = @@log
      GoodData.connect(login,password,server)
    end

    def init_persistent_storage
      @projects = Project.new()
      @etl = Etl.new()
      @user = User.new()
    end


    def project_provisioning
      fail "Persistent storage not initialized" if @projects.nil?
      Helper.retryable do
        @projects.create_projects
      end
    end

    def etl_provisioning
      fail "Persistent storage not initialized" if @etl.nil?
      Helper.retryable do
        @etl.deploy_process
        @etl.create_schedules
        @etl.create_notifications
      end
    end

    def user_synchronization
      fail "Persistent storage not initialized" if @user.nil?

      #Helper.retryable do
      #  @
      #  @etl.create_schedules
      #  @etl.create_notifications
      #end

    end


    def update_schedules()
      @@log.info "Starting schedule update"
      Persistent.reset_schedule_update
      Helper.retryable do
        @etl.update_schedules
      end
    end





    def delete_all_projects
      list = GoodData.get("gdc/md/")
      list["about"]["links"].each do |p|
        project = GoodData::Project[p["identifier"]]
        project.delete
      end


    end







  end


end