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






  end
end