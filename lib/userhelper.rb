module PowerByHelper

  class UserHelper


    def self.create_user_in_domain(domain,user_data)

        account_setting = {
            "accountSetting" => {
                "login"              => user_data.login,
                "password"           => user_data.password,
                "verifyPassword"     => user_data.password,
                "firstName"          => user_data.first_name,
                "lastName"           => user_data.last_name
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

    def self.add_user_to_project(user_project_data)
      # Two possible ways of adding user to project (with invitation mail / without invitation mail)



    end

    def self.invite_user()
      Persistent.user_project_data.each do |user_project_data|
        if (user_project_data.status == UserProjectData.NEW and user_project_data.notification and !user_project_data.notification_send)
          user_data = Persistent.get_user_by_login(user_project_data.login)
          @@log.info "Inviting user #{user_data.login} to project #{user_project_data.project_pid} (with notification)"
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
        end
      end
    end


    def self.add_user()
      Persistent.user_project_data.each do |user_project_data|
        if (user_project_data.status == UserProjectData.NEW and !user_project_data.notification)
          user_data = Persistent.get_user_by_login(user_project_data.login)
          request = create_user_request("ENABLED",user_data.uri,Persistent.get_role_uri_by_name(user_project_data.role,user_project_data.project_pid))
          begin
            @@log.info "Adding user #{user_data.login} to project #{user_project_data.project_pid} (without notification)"
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







  end
end