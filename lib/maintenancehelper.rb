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



    def self.execute_maql(project_data,maql)
      maql = {
          "manage" => {
              "maql" => maql
          }

      }
      begin
        result = GoodData.post("/gdc/md/#{project_data.project_pid}/ldm/manage", maql)
        return result
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




    def self.create_user_in_domain(domain,user_data)

        account_setting = {
            "accountSetting" => {
                "login"              => user_data.login,
                "password"           => user_data.password,
                "verifyPassword"     => user_data.password,
                "firstName"          => user_data.first_name || "John" ,
                "lastName"           => user_data.last_name || "Doe"
            }
        }

        begin
          result = GoodData.post("/gdc/account/domains/#{domain}/users", account_setting)
          user_data.uri = result["uri"]
          user_data.status = UserData.CREATED
          return user_data
        rescue RestClient::BadRequest => e
          response = JSON.load(e.response)
          @@log.warn "User #{user_data.login} could not be created. Reason: #{response["error"]["message"]}"
          return
        rescue RestClient::InternalServerError => e
          response = JSON.load(e.response)
          @@log.warn "User #{user_data.login} could not be created and returned 500. Reason: #{response["error"]["message"]}"
          return
        end
    end



  end
end