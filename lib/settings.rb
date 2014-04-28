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
        if (!@json["deployment"]["user"].nil? and !@json["deployment"]["user"]["creation"].nil?)
          @json["deployment"]["user"]["creation"]["type"] || "local"
        else
          "local"
        end
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
        if (!@json["deployment"]["user"].nil? and !@json["deployment"]["user"]["project_synchronization"].nil?)
          @json["deployment"]["user"]["project_synchronization"]["type"] || "local"
        else
          "local"
        end
      end

      def deployment_user_project_synchronization_move_after_processing
        @json["deployment"]["user"]["project_synchronization"]["move_after_processing_to"]
      end


      def default_user_project_synchronization_data_file_name
        "source/user_projects.csv"
      end


      def deployment_mufs
        @json["deployment"]["mufs"]
      end

      def deployment_mufs_file_pattern
        deployment_mufs["file_pattern"]
      end





      def deployment_mufs_source_dir
        if (deployment_mufs["source_dir"].nil?)
          "source/mufs/"
        else
          deployment_mufs["source_dir"]
        end
      end


      def deployment_mufs_remote_dir
        if (deployment_mufs["remote_dir"].nil?)
          ""
        else
          deployment_mufs["remote_dir"]
        end
      end



      def deployment_mufs_user_id_field
        deployment_mufs["user_id_field"] || "login"
      end

      def deployment_mufs_use_cache
        if ((deployment_mufs.nil?) or (deployment_mufs["use_cache"].nil?))
          true
        else
          deployment_mufs["use_cache"]
        end
      end

      def deployment_mufs_type
        if ((deployment_mufs.nil?) or (deployment_mufs["type"].nil?))
          "local"
        else
          deployment_mufs["type"]
        end
      end



      def deployment_mufs_webdav_folder_target
        if ((deployment_mufs.nil?) or (deployment_mufs["webdav_folder_target"].nil?))
          "loaded/"
        else
          deployment_mufs["webdav_folder_target"]
        end
      end



      def deployment_mufs_muf
        deployment_mufs["muf"]
      end

      def deployment_mufs_empty_value
        deployment_mufs["empty_value"] || "TRUE"
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

      def storage_maintenance_source
        if  (!@json["storage"].nil? and !@json["storage"]["maintenance"].nil?)
          @json["storage"]["maintenance"]["source"] || "data/maintenance.csv"
        else
          "data/maintenance.csv"
        end
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

      def storage_schedules_source
        if  (!@json["storage"].nil? and !@json["storage"]["etl"].nil?)
          @json["storage"]["schedules"]["source"] || "data/schedules.csv"
        else
          "data/schedules.csv"
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


      def storage_muf_source
        if  (!@json["storage"].nil? and !@json["storage"]["muf"].nil?)
          @json["storage"]["muf"]["source"] || "data/muf.yaml"
        else
          "data/muf.yaml"
        end
      end








  end

  end







end