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
        pp "fakt"
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