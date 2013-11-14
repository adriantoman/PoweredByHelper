module PowerByHelper

  class Settings

  class << self

      def load(json)
        @json = json
      end

      def connection
        @json["connection"]
      end

      def connection_server
        @json["connection"]["server"] || "https://secure.gooddata.com"
      end

      def connection_webdav
        @json["connection"]["webdav"] || "https://secure-di.gooddata.com"
      end

      def connection_webdav_storage
        @json["connection"]["webdav_storage"]
      end

      def deployment_project
        @json["deployment"]["project"]
      end



      def deployment_project_name_prefix
        @json["deployment"]["project"]["name_prefix"] || ""
      end

      def deployment_project_data_file_name
        @json["deployment"]["project"]["data"]["file_name"]
      end

      def default_project_data_file_name
        "source/projects.csv"
      end

      def deployment_project_data_type
        @json["deployment"]["project"]["data"]["type"] || "local"
      end

      def deployment_project_data_move_after_processing
        @json["deployment"]["project"]["data"]["move_after_processing_to"]
      end

      def deployment_project_delete
        @json["deployment"]["project"]["delete"]
      end

      def deployment_project_disable_duration
        @json["deployment"]["project"]["disable_duration"] || 30
      end


      def deployment_source
        @json["deployment"]["source"]
      end

      def deployment_etl
        @json["deployment"]["etl"]
      end


      def deployment_etl_process
        @json["deployment"]["etl"]["process"]
      end

      def deployment_etl_schedule
        @json["deployment"]["etl"]["schedule"]
      end

      def deployment_etl_notifications
        @json["deployment"]["etl"]["notifications"]
      end


      def deployment_user
        @json["deployment"]["user"]
      end


      def deployment_user_domain
        @json["deployment"]["user"]["domain"]
      end


      def deployment_user_creation
        @json["deployment"]["user"]["creation"]
      end

      def deployment_user_creation_type
        @json["deployment"]["user"]["creation"]["type"] || "local"
      end

      def deployment_user_creation_move_after_processing
        @json["deployment"]["user"]["creation"]["move_after_processing_to"]
      end

      def default_user_data_file_name
        "source/users.csv"
      end

      def deployment_user_project_synchronization
        @json["deployment"]["user"]["project_synchronization"]
      end

      def deployment_user_project_synchronization_type
        @json["deployment"]["user"]["project_synchronization"]["type"] || "local"
      end

      def deployment_user_project_synchronization_move_after_processing
        @json["deployment"]["user"]["project_synchronization"]["move_after_processing_to"]
      end


      def default_user_project_synchronization_data_file_name
        "source/user_projects.csv"
      end


      def provisioning
        @json["provisioning"]
      end

      def customer
        @json["customer"]
      end


      def storage
        @json["storage"]
      end

      def storage_project_source
        if  (!@json["storage"].nil? and !@json["storage"]["project"].nil?)
          @json["storage"]["project"]["source"] || "data/project.csv"
        else
          "data/project.csv"
        end
      end

      def storage_etl_source
        if  (!@json["storage"].nil? and !@json["storage"]["etl"].nil?)
          @json["storage"]["etl"]["source"] || "data/etl.csv"
        else
          "data/etl.csv"
        end
      end

      def storage_user_source
        if  (!@json["storage"].nil? and !@json["storage"]["user"].nil?)
          @json["storage"]["user"]["source"] || "data/user.csv"
        else
          "data/user.csv"
        end


      end


      def storage_user_project_source
        if  (!@json["storage"].nil? and !@json["storage"]["user"].nil?)
          @json["storage"]["user_project"]["source"] || "data/user_project.csv"
        else
          "data/user_project.csv"
        end


      end






  end

  end







end