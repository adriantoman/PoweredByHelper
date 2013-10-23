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


  end
end