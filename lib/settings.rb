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

      def deployment_project
        @json["deployment"]["project"]
      end

      def deployment_project_name_prefix
        @json["deployment"]["project"]["name_prefix"] || ""
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

      def deployment_user_project_synchronization
        @json["deployment"]["user"]["project_synchronization"]
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
        if  (!@json["storage"]["project"].nil?)
          @json["storage"]["project"]["source"] || "data/project.csv"
        else
          "data/project.csv"
        end
      end

      def storage_etl_source
        if  (!@json["storage"]["etl"].nil?)
          @json["storage"]["etl"]["source"] || "data/etl.csv"
        else
          "data/etl.csv"
        end
      end

      def storage_user_source
        if  (!@json["storage"]["user"].nil?)
          @json["storage"]["user"]["source"] || "data/user.json"
        else
          "data/user.json"
        end


      end





  end

  end







end