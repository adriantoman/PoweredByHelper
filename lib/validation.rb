# encoding: UTF-8
module PowerByHelper

  class Validation


    class << self

      def project_definition
         [
            { "id" => "project_name",
              "type" => "string",
              "min_size" => 1
            },
            {   "id" => "ident",
                "type" => "string",
                "min_size" => 1
            }
        ]
      end


      def user_definition
          [
              {
                  "id" => "login",
                  "type" => "email",
                  "min_size" => 1
              },
              {
                  "id" => "first_name",
                  "type" => "string",
              },
              {
                  "id" => "last_name",
                  "type" => "string"
              },
              {
                  "id" => "password",
                  "type" => "string"
              },
              {
                  "id" => "super_admin",
                  "type" => "enum",
                  "enum" => ["adminrole","connectorssystemrole","editorrole","dashboardonlyrole","unverifiedadminrole","readonlyuserrole","0","1"]
              }
          ]
      end

      def user_project_definition
        [
            {
                "id" => "ident",
                "type" => "string",
                "min_size" => 1
            },
            {
                "id" => "login",
                "type"  => "email",
                "min_size" => 1
            },
            {
                "id" =>   "role",
                "type" => "enum",
                "enum" => ["adminrole","connectorssystemrole","editorrole","dashboardonlyrole","unverifiedadminrole","readonlyuserrole"]
            },
            {
                "id" => "notification",
                "type" => "enum",
                "enum" => ["0","1"]
            },
            {
                "id" =>   "internal_role",
                "type" => "enum",
                "enum" => ["internal","external"]
            }
        ]
      end


      def validate_field(field, definition)
        message = ""
        error = false
        if (definition["type"] =~ /email/ and !error)
          if (field.nil? or field.length == 0)
            message = "is empty"
            error = true
          elsif !(/^(([A-Za-z0-9]+_+)|([A-Za-z0-9]+\-+)|([A-Za-z0-9]+\.+)|([A-Za-z0-9]+\++))*[A-Z‌​a-z0-9]+@((\w+\-+)|(\w+\.))*\w{1,63}\.[a-zA-Z]{2,6}$/i =~ field)
            message = "is not valid email adress"
            error = true
          end
        end
        if (definition["type"] =~ /string/ and !error)
          if (!definition["min_size"].nil?)
            if (field.nil? or field.length < definition["min_size"])
              message = "is empty"
              error = true
            end
          end
        end
        if (definition["type"] =~ /enum/ and !error)
          enum = definition["enum"]
          if (field.nil? or field.length == 0)
            message = "is empty"
            error = true
          elsif (!enum.include?(field.to_s.downcase))
            message = "is not in list of valid values"
            error = true
          end
        end
        if (definition["type"] =~ /integer/ and !error)
          if (field.nil?)
            message = "is empty"
            error = true
          elsif (!field.instance_of?(Integer))
            begin
              Integer(field)
            rescue => e
              message = "is not number"
              error = true
            end
          end
        end
        if (error)
          message
        else
          nil
        end
      end


      def validate_project_file(file_location)
        @@log.info "Project file validation:"
        error = false
        line_number = 2
        FasterCSV.foreach(file_location, {:headers => true, :skip_blanks => true}) do |csv_obj|
          Validation.project_definition.each do |field|
            key = field["id"]
            if (!Settings.deployment_project_data_mapping[key].nil?)
              value = csv_obj[Settings.deployment_project_data_mapping[key]]
              response = Validation.validate_field(value,field)
              if (!response.nil?)
                @@log.info "The field in column #{Settings.deployment_project_data_mapping[key]} on line #{line_number} #{response}"
                error = true
              end
            else
              fail "The source file don't have field #{Settings.deployment_project_data_mapping[key]}"
            end
          end
          line_number += 1
        end
        @@log.info "Project file validation has finished"
        error
      end

      def validate_user_file(file_location)
        @@log.info "User file validation:"
        error = false
        line_number = 2
        FasterCSV.foreach(file_location, {:headers => true, :skip_blanks => true}) do |csv_obj|
          Validation.user_definition.each do |field|
            key = field["id"]
            if (!Settings.deployment_user_creation_mapping[key].nil?)
              value = csv_obj[Settings.deployment_user_creation_mapping[key]]
              response = Validation.validate_field(value,field)
              if (!response.nil?)
                @@log.info "The field in column #{Settings.deployment_user_creation_mapping[key]} on line #{line_number} #{response}"
                error = true
              end
            else
              fail "The source file don't have field #{Settings.deployment_user_creation_mapping[key]}"
            end
          end
          line_number += 1
        end
        @@log.info "User file validation has finished"
        error
      end

      def validate_user_project_file(file_location)
        @@log.info "User project file validation:"
        error = false
        line_number = 2
        FasterCSV.foreach(file_location, {:headers => true, :skip_blanks => true}) do |csv_obj|
          Validation.user_project_definition.each do |field|
            key = field["id"]
            if (!Settings.deployment_user_project_synchronization_mapping[key].nil?)
              value = csv_obj[Settings.deployment_user_project_synchronization_mapping[key]]
              response = Validation.validate_field(value,field)
              if (!response.nil?)
                @@log.info "The field in column #{Settings.deployment_user_project_synchronization_mapping[key]} on line #{line_number} #{response}"
                error = true
              end
            else
              fail "The source file don't have field #{Settings.deployment_user_project_synchronization_mapping[key]}"
            end
          end
          line_number += 1
        end
        @@log.info "User project file validation has finished"
        error
      end
      end
    end

end
