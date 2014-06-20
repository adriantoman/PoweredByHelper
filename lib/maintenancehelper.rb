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

  class MaintenanceHelper



    def self.execute_maql(maintenance_data,maql_source)
      maql = {
          "manage" => {
              "maql" => maql_source
          }

      }
      begin
        result = GoodData.post("/gdc/md/#{maintenance_data.project_pid}/ldm/manage2", maql)
        return result
      rescue RestClient::BadRequest => e
        response = JSON.load(e.response)
        @@log.warn "The maql could not be applied on project #{maintenance_data.project_pid}. Reason: #{response["error"]["message"]}"
        return nil
      rescue RestClient::InternalServerError => e
        response = JSON.load(e.response)
        @@log.warn "The maql could not be applied on project #{maintenance_data.project_pid} and returned 500. Reason: #{response["error"]["message"]}"
        return nil
      rescue => e
        response = JSON.load(e.response)
        @@log.warn "Unknown error - The maql could not be applied on project #{maintenance_data.project_pid} and returned 500. Reason: #{response["error"]["message"]}"
        return nil
      end
    end

    def self.check_task_status(maintenance_data)
      begin
        result = GoodData.get("/gdc/md/#{maintenance_data.project_pid}/tasks/#{maintenance_data.task_id}/status")
        status = result["wTaskStatus"]["status"]
        if (status == "ERROR")
          @@log.warn "MAQL request for project: #{maintenance_data.project_pid} has failed. Reason: #{result}"
        end
        return status
      rescue RestClient::BadRequest => e
        response = JSON.load(e.response)
        @@log.warn "User #{user_data.login} could not be created. Reason: #{response["error"]["message"]}"
        return nil
      rescue RestClient::InternalServerError => e
        response = JSON.load(e.response)
        @@log.warn "User #{user_data.login} could not be created and returned 500. Reason: #{response["error"]["message"]}"
        return nil

      end
    end


    def self.execute_partial_import(maintenance_data,token)
      json = {
          "partialMDImport" => {
              "token" => "#{token}",
              "overwriteNewer" => "1",
              "updateLDMObjects" => "0"
        }
      }
      begin
        result = GoodData.post("/gdc/md/#{maintenance_data.project_pid}/maintenance/partialmdimport", json)
        return result
      rescue RestClient::BadRequest => e
        response = JSON.load(e.response)
        @@log.warn "The partial metadata could not be applied on project #{maintenance_data.project_pid}. Reason: #{response["error"]["message"]}"
        return nil
      rescue RestClient::InternalServerError => e
        response = JSON.load(e.response)
        @@log.warn "The partial metadata could not be applied on project #{maintenance_data.project_pid} and returned 500. Reason: #{response["error"]["message"]}"
        return nil
      rescue => e
        response = JSON.load(e.response)
        pp response
        @@log.warn "Unknown error - The maql could not be applied on project #{maintenance_data.project_pid} and returned 500. Reason: #{response["message"]}"
        return nil
      end
    end

    def self.create_update_value(maintenance_data,key,value)
      # TO DO  - add pagging
      result = GoodData.get("/gdc/projects/#{maintenance_data.project_pid}/dataload/metadata")
      values = {}
      result["metadataItems"]["items"].each do |e|
        key_temp = e["metadataItem"]["key"]
        value_temp = e["metadataItem"]["value"]
        values[key_temp] = value_temp
      end
      json =
        {"metadataItem" =>
              {"key" => key,
              "value" => value}
        }

      begin
        result = nil
        if values.has_key?(key)
          result = GoodData.put("/gdc/projects/#{maintenance_data.project_pid}/dataload/metadata/#{key}", json)
        else
          result = GoodData.post("/gdc/projects/#{maintenance_data.project_pid}/dataload/metadata", json)
        end
        return result
      rescue RestClient::BadRequest => e
        response = JSON.load(e.response)
        @@log.warn "The key/value storage could not be change for project #{maintenance_data.project_pid}. Reason: #{response["error"]["message"]}"
        return nil
      rescue RestClient::InternalServerError => e
        response = JSON.load(e.response)
        @@log.warn "The key/value storage could not be change for project #{maintenance_data.project_pid} and returned 500. Reason: #{response["error"]["message"]}"
        return nil
      rescue => e
        pp e
        response = JSON.load(e.response)
        @@log.warn "Unknown error - The key/value storage could not be change for project #{maintenance_data.project_pid} and returned 500. Reason: #{response["message"]}"
        return nil
      end
    end

    def self.create_backup(folder,filename)
      res = nil
      processed_files = []
      Zip::ZipFile.open(folder + filename + "_#{DateTime.now.strftime("%Y%m%dT%H%M")}.zip", Zip::ZipFile::CREATE) do |zipfile|
        Dir["data/*"].each do |file|
          unless File.directory?(file)
            zipfile.add(file.sub("data/",''), file)
          end
        end
      end
    end

  end
end