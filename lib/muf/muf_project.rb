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

  class MufProject

    attr_accessor :pid,:elements_lookup,:ident,:muf_logins

    def initialize(ident,pid,input_elements_lookup = nil)
      @muf_logins = []
      @elements_lookup = {}
      @ident = ident
      @pid = pid


      #load_element_lookup()
      #if input_elements_lookup.nil?
      #  load_element_lookup()
      #else
      #  @elements_lookup = input_elements_lookup
      #end
    end

    def add_login(muf_login)
      @muf_logins.push(muf_login)
    end

    def find_login_by_login(login)
      @muf_logins.find{|muf_login| muf_login.login == login }
    end

    def lookup_loaded?(attibute)
      @elements_lookup.has_key?(attibute)
    end

    def load_element_lookup(attribute,element)
      @@log.info "Loading elements lookup for project:#{@pid} and element: #{element}"
      element_hash = {}
      response = GoodData.get(Helper.get_element_object_url(@pid,element))
      response["attributeElements"]["elements"].each do |item|
        element_hash[item["title"]] = item["uri"]
      end
      @elements_lookup[attribute] = element_hash
    end

    def find_element_by_value(attribute,value)
      @elements_lookup[attribute][value]
    end

    def create_update_filter(login,expression,url = nil)
      filter = {
          "userFilter" => {
              "content" => {
                  "expression" => expression
              },
              "meta" => {
                  "category" => "userFilter",
                  "title" => "Filter for login: #{login} and pid: #{@pid} by PBH"
              }
          }
      }

      begin
        if (url.nil?)
          result = GoodData.post("/gdc/md/#{@pid}/obj",filter )
        else
          result = GoodData.post(url,filter)
        end
      rescue RestClient::BadRequest => e
        response = JSON.load(e.response)
        @@log.warn "User filter for login: #{login} and pid #{@pid} could not be created/updated. Reason: #{response["error"]["message"]}"
      rescue RestClient::InternalServerError => e
        response = JSON.load(e.response)
        @@log.warn "User filter for login: #{login} and pid #{@pid} could not be created/updated. Reason: #{response["error"]["message"]}"
      rescue => e
        @@log.warn "User filter for login:#{login} and pid #{@pid} could not be created/updated. Reason: Unknown reason"
      end
      result["uri"]
    end


    def delete_filter(url)
      begin
        result = GoodData.delete(url)
      rescue RestClient::BadRequest => e
        response = JSON.load(e.response)
        @@log.warn "User filter for login: #{login} and pid #{@pid} could not be created/updated. Reason: #{response["error"]["message"]}"
      rescue RestClient::InternalServerError => e
        response = JSON.load(e.response)
        @@log.warn "User filter for login: #{login} and pid #{@pid} could not be created/updated. Reason: #{response["error"]["message"]}"
      rescue => e
        @@log.warn "User filter for login:#{login} and pid #{@pid} could not be created/updated. Reason: Unknown reason"
      end
      result
    end

    def apply_filter(login,filter_url)
      user_data = Persistent.get_user_by_login(login)
      user_filter = {
          "userFilters" => {
              "items" => [
                  {
                      "user" => user_data.uri,
                      "userFilters" => [ filter_url ]
                  }
              ]
          }
      }

      begin
        result = GoodData.post "/gdc/md/#{@pid}/userfilters", user_filter
      rescue RestClient::BadRequest => e
        response = JSON.load(e.response)
        @@log.warn "User filter for project: #{@pid} could not be created/updated. Reason: #{response["error"]["message"]}"
      rescue RestClient::InternalServerError => e
        response = JSON.load(e.response)
        @@log.warn "User filter for project: #{@pid} could not be created/updated. Reason: #{response["error"]["message"]}"
      rescue => e
        @@log.warn "User filter for project: #{@pid} could not be updated. Reason: Unknown reason"
      end
      result
    end

    #-------------------------------------------------------------------------------------
    #------------OLD SHIT-----------------------------------------------------------





  end

end