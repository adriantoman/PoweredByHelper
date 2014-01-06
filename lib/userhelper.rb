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

  class UserHelper


    def self.create_user_in_domain(domain,user_data)

        account_setting = {
            "accountSetting" => {
                "login"              => user_data.login,
                "password"           => user_data.password,
                "verifyPassword"     => user_data.password,
                "firstName"          => user_data.first_name || "John" ,
                "lastName"           => user_data.last_name || "Doe",
                "ssoProvider"        => user_data.sso_provider
            }
        }

        begin
          result = GoodData.post("/gdc/account/domains/#{domain}/users", account_setting)
          Persistent.change_user_status(user_data.login,UserData.CREATED,{"uri" => result["uri"]})
          Persistent.store_user
          return
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


    def self.change_user(user_data)
      account_setting = {
          "accountSetting" => {
              "firstName"          => user_data.first_name || "John" ,
              "lastName"           => user_data.last_name || "Doe",
              "ssoProvider"        => user_data.sso_provider
          }
      }

      begin
        @@log.info "Changing user #{user_data.login} - first_name: #{user_data.first_name} last_name: #{user_data.last_name} sso_provider: #{user_data.sso_provider}"
        result = GoodData.put(user_data.uri, account_setting)
        Persistent.change_user_status(user_data.login,UserData.CREATED,{})
        Persistent.store_user
        return
      rescue RestClient::BadRequest => e
        response = JSON.load(e.response)
        @@log.warn "Data for user #{user_data.login} could not be changed. Reason: #{response["error"]["message"]}"
        return
      rescue RestClient::InternalServerError => e
        response = JSON.load(e.response)
        @@log.warn "Data for user #{user_data.login} could not be changed and returned 500. Reason: #{response["error"]["message"]}"
        return
      end



    end


    def self.add_user_to_project(user_project_data)
      # Two possible ways of adding user to project (with invitation mail / without invitation mail)

    end

    def self.change_users()
      Persistent.user_data.each do |user_data|
        if (user_data.status == UserData.CHANGED)
          change_user(user_data)
        end

      end


    end


    def self.invite_user()
      Persistent.user_project_data.each do |user_project_data|
        if (user_project_data.status == UserProjectData.NEW and user_project_data.notification and !user_project_data.notification_send)
          user_data = Persistent.get_user_by_login(user_project_data.login)
          if (!user_data.nil? and user_data.status == UserData.CREATED)
            @@log.info "Inviting user #{user_data.login} to project #{user_project_data.project_pid} (#{user_project_data.role}) (with notification)"
            request = {
                "invitations" =>
                  [{
                      "invitation" => {
                       "content"=> {
                           "email"=> user_data.login,
                           "role"=> Persistent.get_role_uri_by_name(user_project_data.role,user_project_data.project_pid),
                           "firstname"=> "GoodData",
                           "lastname"=> "",
                           "action"=> {
                               "setMessage"=> Settings.deployment_user_project_synchronization["notification_message"]
                          }
                      }
                  }
                }]
              }
            begin
              GoodData.post("/gdc/projects/#{user_project_data.project_pid}/invitations", request)
              Persistent.change_user_project_status(user_project_data.login,user_project_data.project_pid,UserProjectData.OK,{"notification_send" => true})
              Persistent.store_user_project
            rescue RestClient::BadRequest => e
              response = JSON.load(e.response)
              @@log.warn "User #{user_data_element.login} could not be invited to project #{user_project_data.project_pid}. Reason: #{response["error"]["message"]}"
            rescue RestClient::InternalServerError => e
              response = JSON.load(e.response)
              @@log.warn "User #{user_data_element.login} could not be invited to project #{user_project_data.project_pid}. Reason: #{response["error"]["message"]}"
            end
          else
            @@log.warn "Skipping invite of user #{user_project_data.login} to project #{user_project_data.project_pid} (with notification) - problem with domain user"
          end
        end
      end
    end


    def self.add_user()
      Persistent.user_project_data.each do |user_project_data|
        if (user_project_data.status == UserProjectData.NEW and !user_project_data.notification)
          user_data = Persistent.get_user_by_login(user_project_data.login)
          if (!user_data.login.nil? and user_data.status == UserData.CREATED)
            request = create_user_request("ENABLED",user_data.uri,Persistent.get_role_uri_by_name(user_project_data.role,user_project_data.project_pid))
            begin
              @@log.info "Adding user #{user_data.login} to project #{user_project_data.project_pid} (#{user_project_data.role}) (without notification)"
              GoodData.post("/gdc/projects/#{user_project_data.project_pid}/users", request)
              Persistent.change_user_project_status(user_project_data.login,user_project_data.project_pid,UserProjectData.OK,nil)
              Persistent.store_user_project
            rescue RestClient::BadRequest => e
              response = JSON.load(e.response)
              @@log.warn "User #{user_project_data.login} could not be added to project #{user_project_data.project_pid}. Reason: #{response["error"]["message"]}"
            rescue RestClient::InternalServerError => e
              response = JSON.load(e.response)
              @@log.warn "User #{user_project_data.login} could not be added to project #{user_project_data.project_pid}. Reason: #{response["error"]["message"]}"
            end
          else
            @@log.warn "Skipping invite of user #{user_project_data.login} to project #{user_project_data.project_pid} (without notification) - problem with domain user"
          end
        end
      end
    end


    def self.disable_user()
      Persistent.user_project_data.each do |user_project_data|
        begin
          user_data = Persistent.get_user_by_login(user_project_data.login)
          if (user_project_data.status == UserProjectData.TO_DISABLE)
            request = create_user_request("DISABLED",user_data.uri)
            @@log.info "Disabling user #{user_data.login} in project #{user_project_data.project_pid}"
            GoodData.post("/gdc/projects/#{user_project_data.project_pid}/users", request)
            Persistent.change_user_project_status(user_project_data.login,user_project_data.project_pid,UserProjectData.DISABLED,nil)
            Persistent.store_user_project
          elsif (user_project_data.status == UserProjectData.TO_DISABLE_BY_PROJECT and user_project_data.internal_role != "internal")
            request = create_user_request("DISABLED",user_data.uri)
            @@log.info "Disabling user #{user_data.login} in project #{user_project_data.project_pid}"
            GoodData.post("/gdc/projects/#{user_project_data.project_pid}/users", request)
            Persistent.change_user_project_status(user_project_data.login,user_project_data.project_pid,UserProjectData.DISABLED,nil)
            Persistent.store_user_project
          end
        rescue RestClient::BadRequest => e
          response = JSON.load(e.response)
          @@log.warn "User #{user_data.login} could not be disabled in project #{user_project_data.project_pid}. Reason: #{response["error"]["message"]}"
        rescue RestClient::InternalServerError => e
          response = JSON.load(e.response)
          @@log.warn "User #{user_data.login} could not be disabled in project #{user_project_data.project_pid}. Reason: #{response["error"]["message"]}"
        end
      end
    end

    def self.update_user()
      Persistent.user_project_data.each do |user_project_data|
        if (user_project_data.status == UserProjectData.CHANGED)
          user_data = Persistent.get_user_by_login(user_project_data.login)
          request = create_user_request("ENABLED",user_data.uri,Persistent.get_role_uri_by_name(user_project_data.role,user_project_data.project_pid))

          begin
            @@log.info "Updating user #{user_data.login} in project #{user_project_data.project_pid} (role - #{user_project_data.role}, status - ENABLED)"
            GoodData.post("/gdc/projects/#{user_project_data.project_pid}/users", request)
            Persistent.change_user_project_status(user_project_data.login,user_project_data.project_pid,UserProjectData.OK,nil)
            Persistent.store_user_project
          rescue RestClient::BadRequest => e
            response = JSON.load(e.response)
            @@log.warn "User #{user_data.login} could not be updated or re-enabled in project #{user_project_data.project_pid}. Reason: #{response["error"]["message"]}"
          rescue RestClient::InternalServerError => e
            response = JSON.load(e.response)
            @@log.warn "User #{user_data.login} could not be updated or re-enabled in project #{user_project_data.project_pid}. Reason: #{response["error"]["message"]}"
          end
        end
      end
    end





    def self.create_user_request(status,uri,role = nil)
      request ={
          "user" => {
              "content" => {
                  "status"=> status
              },
              "links"   => {
                  "self"=> uri
              }
          }
      }
      if (!role.nil?)
        request["user"]["content"].merge!({"userRoles" => [role]})
      end
      request
    end


    def self.load_domain_users
      @@log.info "Loading users from domain"
      users = []
      finished = false
      offset = 0
      # Limit set to 1000 to be safe
      limit = 1000

      while (!finished) do
        @@log.info "Loading users from domain offset=#{offset} limit=#{limit}"
        response = GoodData.get("/gdc/account/domains/#{Settings.deployment_user_domain}/users?offset=#{offset}&limit=#{limit}")
        response["accountSettings"]["items"].each do |item|
          user_hash = {:login => item["accountSetting"]["login"],:profile => item["accountSetting"]["links"]["self"]}
          users.push(user_hash)
        end
        if (response["accountSettings"]["items"].count == limit) then
          offset = offset + limit
        else
          finished = true
        end
      end
      users
    end

  end
end