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


  class Ads

    attr_accessor :name_prefix,:token,:template

    def initialize()
      load_data_structure()
    end

    def load_data_structure()
      ads_token = Settings.deployment_ads_token
      fail "The ads authorization token is not filled" if ads_token.nil?

      Persistent.init_ads
      update_project_params

      Persistent.project_data.each do |project|
        if (project.status == ProjectData.OK)
          Persistent.change_ads_status(project.ident,AdsData.NEW,{"project_ident" => project.ident})
        end
      end

      @@log.info "Persistent storage for asd provisioning initialized"
    end

    def provision_ads
      @@log.info "Starting ADS provisioning"
      Persistent.ads_data.each do |ads|
        if (ads.status == AdsData.NEW)
          project = Persistent.get_project_by_ident(ads.project_ident)
          pp project
          if (!project.ads.nil?)
            Persistent.change_ads_status(ads.project_ident,AdsData.OK,{"ident" => project.ads })
            Persistent.store_ads
            @@log.info "ADS for project #{project.project_name}(#{project.project_pid}) taken from initial setup. New ADS was not created"

          else
            request = {
                "dssInstance" => {
                    "title" => "Provisioned ADS for #{project.project_name}(#{project.project_pid})",
                    "authorizationToken" => "#{Settings.deployment_ads_token}",
                    "description" =>  "ADS provisioned by PoweredByHelper"
                }
            }
            begin
              result = GoodData.post("/gdc/dss/instances/",request)
              poll = result["asyncTask"]["links"]["poll"]
              loop_id = 0
              loop do
                response = GoodData.get(poll)
                if (response["asyncTask"]["links"].include?("dssInstance"))
                  ads_ident = response["asyncTask"]["links"]["dssInstance"].split("/").last
                  Persistent.change_ads_status(ads.project_ident,AdsData.OK,{"ident" => ads_ident})
                  Persistent.store_ads
                  @@log.info "ADS for project #{project.project_name}(#{project.project_pid}) created with id #{ads_ident}."
                  break
                elsif (loop_id > 500)
                  @@log.warn "The creation of ADS for project #{project.project_name}(#{project.project_pid}) has timeout after 500 pools"
                  Persistent.change_ads_status(ads.project_ident,AdsData.NEW,{})
                  Persistent.store_ads
                  break
                end
                loop_id = loop_id + 1
                sleep(5)
              end
            rescue RestClient::BadRequest => e
              response = JSON.load(e.response)
              @@log.warn "The ads could not be create for project: #{project.project_pid}. Reason: #{response["error"]["message"]}"
            rescue RestClient::InternalServerError => e
              response = JSON.load(e.response)
              @@log.warn "The ads could not be create for project: #{project.project_pid}.Returned 500 and Reason: #{response["error"]["message"]}"
            rescue => e
              pp e
              response = JSON.load(e.response)
              @@log.warn "Unknown error - The ads could not be create for project: #{project.project_pid}. Reason: #{response["error"]["message"]}"
            end
          end
        end
      end
      update_project_params
      @@log.info "ADS provisioning has finished"
    end



    def update_project_params
      Persistent.ads_data.each do |ads|
        if (ads.status == AdsData.OK)
          params = Persistent.project_custom_params.find{|p| p.keys.first == ads.project_ident}
          value = params.values.first.find{|a| a.keys.first == "ADS"}
          if (value.nil?)
            value = {"ADS" => ""}
            params.values.first << value
          end
          value["ADS"] = ads.ident
        end
      end
    end
  end


  class AdsData

    attr_accessor :ident,:project_ident,:status

    def self.NEW
      "NEW"
    end


    def self.IN_PROGRESS
      "IN_PROGRESS"
    end

    def self.OK
      "OK"
    end

    def self.DELETED
      "DELETED"
    end





    def initialize(status,data)
      @status = status
      @ident = data["ident"] if !data["ident"].nil?
      @project_ident = data["project_ident"] if !data["project_ident"].nil?
      @@log.debug "Setting status to #{@status}"
    end

    def self.header
      ["project_ident","ident","status"]
    end

    def to_a
      [@project_ident,@ident,@status]
    end



  end





end