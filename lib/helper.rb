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

  class Helper


    def self.blank?(value)
      if (value.nil?) or (value.empty?)
        return true
      else
        return false
      end
    end

    def self.roles
      ["adminRole","dashboardOnlyRole","readOnlyUserRole","editorRole","connectorsSystemRole"]
    end

    def self.retryable
      begin
        tries ||= 3
        yield
      rescue => e
        if (tries -= 1) > 0
          @@log.warn "There was error during operation: #{e.message}. Retrying"
          retry
        else
          @@log.error e.message
          fail e.message
        end
      else
        @@log.info "Operation finished"
      end
    end


    def self.replace_custom_parameters(ident,value)
      params = Persistent.project_custom_params.find{|p| p.keys.first == ident}
      changed_value = value
      params.values.first.each do |param_value|
        changed_value = changed_value.gsub("%#{param_value.keys.first}%",param_value.values.first)
      end
      changed_value
    end


    def self.download_file_from_webdav(url,target)
      user =      Settings.connection["login"]
      password =  Settings.connection["password"]

      filename =  url.match(/[^\/]*$/)[0]
      adress = Settings.connection_webdav_storage + url.match(/(.*\/)[^\/]*$/)[1]

      dav = Net::DAV.new(adress, :curl => false)
      dav.verify_server = false # Ignore server verification
      dav.credentials(user, password)

      # Create directory if it not exists
      FileUtils.mkdir_p File.dirname(target) if !File.exists?(target)

      @@log.info "Downloading file #{filename} from #{adress} to #{target}"
      exist = false
      dav.find('.',:recursive=>false,:filename=> filename) do | item |
        File.open(target, 'w') { |file| file.write(item.content) }
        exist = true
      end
      if exist
        @@log.info "Download completed!"
      else
        @@log.info "There was not file to download, using old version!"
      end

    end

    def self.move_file_to_other_folder(source,target)
      user =      Settings.connection["login"]
      password =  Settings.connection["password"]

      if (Helper.check_file_on_webdav(source))
        @@log.info "Moving file #{source} to #{target}"
        adress = Settings.connection_webdav_storage
        dav = Net::DAV.new(adress, :curl => false)
        dav.verify_server = false # Ignore server verification
        dav.credentials(user, password)
        dav.move(source,target)
      end
    end

    def self.check_file_on_webdav(source)
      user =      Settings.connection["login"]
      password =  Settings.connection["password"]

      filename =  source.match(/[^\/]*$/)[0]
      adress = Settings.connection_webdav_storage + source.match(/(.*\/)[^\/]*$/)[1]

      dav = Net::DAV.new(adress, :curl => false)
      dav.verify_server = false # Ignore server verification
      dav.credentials(user, password)
      exist = false
      dav.find('.',:recursive=>false,:filename=> filename) do | item |
        exist = true
      end
      exist
    end



  end
end