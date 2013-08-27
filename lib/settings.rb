module PowerByHelper

  class Settings

  class << self

      def load(json)
        @json = json
      end

      def connection
        @json["connection"]
      end

      def deployment_project
        @json["deployment"]["project"]
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
        @json["storage"]["project"]["source"] || "data/project.csv"
      end

      def storage_etl_source
        @json["storage"]["etl"]["source"] || "data/etl.csv"
      end

      def storage_user_source
        @json["storage"]["user"]["source"] || "data/user.json"
      end





  end

  end







end