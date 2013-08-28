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

    def self.invite_user(user_data_element)
      user_data_element.user_project_mapping.each do |user_project_data|
        if (user_project_data.status == UserProjectData.NEW and user_project_data.notification and !user_project_data.notification_send)

          request = {
              "invitations" =>
                [{
                    "invitation" => {
                     "content"=> {
                         "email"=> user_data_element.login,
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
            user_project_data.status = UserProjectData.OK
            user_project_data.notification_send = true
            Persistent.merge_user_project(user_data_element.login,user_project_data)
          rescue RestClient::BadRequest => e
            response = JSON.load(e.response)
            @@log.warn "User #{user_data_element.login} could not be invite to project #{user_project_data.pid}. Reason: #{response["error"]["message"]}"
          rescue RestClient::InternalServerError => e
            response = JSON.load(e.response)
            @@log.warn "User #{user_data_element.login} could not be invite to project #{user_project_data.pid}. Reason: #{response["error"]["message"]}"
          end
        end
      end
    end





    def self.add_user_to_project()

    end







  end
end