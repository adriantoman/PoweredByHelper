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

  class MufCollection

    attr_accessor :file_project_mapping

    def initialize
      load_data_structure()
    end


    def load_data_structure
      Persistent.init_muf
      @file_project_mapping = {}

      # #In case of remote file location, lets download file to local first
      # if (Settings.deployment_mufs_type == "webdav")
      #   Helper.download_files_from_webdav_by_pattern(Settings.deployment_mufs_remote_dir + Settings.deployment_mufs_file_pattern,Settings.deployment_mufs_source_dir)
      #   #data_file_path = Settings.default_project_data_file_name
      # end


      if (Settings.deployment_mufs_type == "webdav")
        remote_filename = Settings.deployment_mufs_remote_file.split("/").last
        if (Helper.check_file_on_webdav("processing/" + remote_filename))
          @@log.info "Found file in processing folder #{remote_filename}, reusing"
          Helper.download_file_from_webdav("processing/" + remote_filename,Settings.deployment_mufs_source_dir + remote_filename)
          FileUtils.rm Dir.glob(Settings.deployment_mufs_source_dir + "*.csv") if Dir.exists?(Settings.deployment_mufs_source_dir)
          Helper.unzip_file(Settings.deployment_mufs_source_dir + remote_filename,Settings.deployment_mufs_source_dir)
          FileUtils.rm(Settings.deployment_mufs_source_dir + remote_filename)
        elsif (Helper.check_file_on_webdav(Settings.deployment_mufs_remote_file))
          Helper.download_file_from_webdav(Settings.deployment_mufs_remote_file,Settings.deployment_mufs_source_dir + remote_filename)
          FileUtils.rm Dir.glob(Settings.deployment_mufs_source_dir + "*.csv") if Dir.exists?(Settings.deployment_mufs_source_dir)
          Helper.unzip_file(Settings.deployment_mufs_source_dir + remote_filename,Settings.deployment_mufs_source_dir)
          FileUtils.rm(Settings.deployment_mufs_source_dir + remote_filename)
          Helper.move_file_to_other_folder(Settings.deployment_mufs_remote_file,"processing/" + remote_filename)
        end
      end

      fail "Muf data folder don't exists" unless Dir.exists?(Settings.deployment_mufs_source_dir)


      #Lets create list of files which are availible for muf provisioning
      Persistent.project_data.find_all{|project| project.status == ProjectData.OK}.each do |p|
        file_name = Helper.replace_custom_parameters(p.ident,Settings.deployment_mufs_file_pattern)
        if (File.exists?(Settings.deployment_mufs_source_dir + file_name))
          @file_project_mapping[p.ident] = {"project" => p,"file" => file_name}
        end
      end

      if (Settings.deployment_mufs_use_cache)
        Persistent.load_mufs
      else
        load_mufs_from_gooddata()
      end

      @file_project_mapping.each_pair do |k,v|
        muf_project = Persistent.muf_projects.find{|project| project.pid == v["project"].project_pid}
        if (muf_project.nil?)
          # If it don't exists, lets create one
          muf_project = MufProject.new(v["project"].project_pid,k)
          Persitent.muf_projects.push(muf_project)
        end
        Settings.deployment_mufs_muf.each do |muf_setting|
          muf_project.load_element_lookup(muf_setting["attribute"],muf_setting["elements"]) if !muf_project.lookup_loaded?(muf_setting["attribute"])
          FasterCSV.foreach(Settings.deployment_mufs_source_dir + v["file"], :headers => true,:quote_char => '"',:skip_blanks => true) do |csv_obj|
            if (!Helper.blank?(csv_obj[Settings.deployment_mufs_user_id_field]))
              if (!Helper.blank?(csv_obj[muf_setting["csv_header"]]))
                # Lets try if the login has already something set up
                muf_login = muf_project.find_login_by_login(csv_obj[Settings.deployment_mufs["user_id_field"]])
                if (muf_login.nil?)
                  #If muf_login don't exists, lets create one
                  muf_login = MufLogin.new(csv_obj[Settings.deployment_mufs["user_id_field"]],Persistent.get_user_by_login(csv_obj[Settings.deployment_mufs["user_id_field"]]).uri)
                  muf_project.add_login(muf_login)
                end
                muf = muf_login.find_muf_by_attribute(muf_setting["attribute"],muf_setting["type"])
                element_url = muf_project.find_element_by_value(muf_setting["attribute"],csv_obj[muf_setting["csv_header"]])
                default_element_url = nil
                if !muf_setting["default_element"].nil?
                  default_element_url = muf_project.find_element_by_value(muf_setting["attribute"],muf_setting["default_element"])
                end
                #Lets try to find, if muf exists for this attribute
                if (muf.nil?)
                  # IF not, lets create MUF
                  muf = nil
                  if (muf_setting["type"].downcase == "over")
                    fail "The connection_point_of_access_dataset or connection_point_of_filtered_dataset settting is missing, please at this settings to config file." if !muf_setting.include?("connection_point_of_filtered_dataset") or !muf_setting.include?("connection_point_of_access_dataset")
                    muf = MufOver.new(muf_setting["attribute"],nil,muf_setting["connection_point_of_access_dataset"],muf_setting["connection_point_of_filtered_dataset"],{"default_element_url" => default_element_url})
                  else
                    muf = MufIn.new(muf_setting["attribute"],nil)
                  end
                  muf_login.add_muf(muf)
                end
                if (csv_obj[muf_setting["csv_header"]] != Settings.deployment_mufs_empty_value)
                  muf.add_new_values(element_url,csv_obj[muf_setting["csv_header"]])
                end
              else
                @@log.warn "There is empty value for login #{csv_obj[Settings.deployment_mufs_user_id_field]} in file #{v["file"]} - SKIPPING"
              end
            else
              @@log.warn "There is empty login in file #{v["file"]} - SKIPPING"
            end
          end
        end
      end
    end


    def compare
      Persistent.muf_projects.each do |muf_project|
        muf_project.muf_logins.each do |muf_login|
          muf_login.mufs.each do |muf|
            if (!muf.same?)
              if (muf.new_values.empty?)
                muf.to_delete
              elsif (muf.values.empty?)
                muf.new
              else
                muf.change
                end
            else
              muf.same
            end
          end
        end
      end
    end

    # Lest finds all users which have some change in project
    def work(muf_project,muf_login)
      begin
        muf_login.mufs.each do |muf|
          if (muf.create?)
            # Lets create the filter
            expression = muf.create_gooddata_muf_representation(muf_project.pid)
            @@log.info "Creating muf definition for login: #{muf_login.login} and #{muf.attribute}"
            muf.muf_url = muf_project.create_update_filter(muf_login.login,expression)
            muf_login.change
          elsif (muf.changed?)
            @@log.info "Changing muf definition for login: #{muf_login.login} muf:#{muf.attribute}"
            result = muf_project.create_update_filter(muf_login.login,muf.create_gooddata_muf_representation(muf_project.pid),muf.muf_url)
          elsif (muf.to_delete?)
            # Lets delete them muf
            @@log.info "Deleting muf definition for login: #{muf_login.login} and attribute: #{muf.attribute}"
            result_delete = muf_project.delete_filter(muf.muf_url)
            muf_login.change
          end
        end
        if (muf_login.changed?)
          @@log.info "Applying the muf on login: #{muf_login.login}"
          muf_project.apply_filter(muf_login.login,muf_login.mufs.map{|muf| muf.muf_url})
          muf_login.clear
        end
      rescue => e
        @@log.error "The MUF process has failed"
        @@log.error e.message
      ensure
       Persistent.store_mufs(muf_project)
      end
    end


    # Lest finds all users which have some change in project
    #OBSOLETE

    def work_all
      Persistent.muf_projects.each do |muf_project|
        begin
          muf_project.muf_logins.collect! do |muf_login|
            # Lets iterate through muf_logins and send them to Gooddata.
            if (muf_login.create?)
              # Lets create the filter
              @@log.info "Creating muf definition for login: #{muf_login.login}"
              result_create = muf_project.create_update_filter(muf_login.login,muf_login.get_gooddata_representation(muf_project.pid))
              # Lets apply it on user resource
              @@log.info "Applying the created muf on login: #{muf_login.login}" if !result_create.nil?
              result_apply = muf_project.apply_filter(muf_login.login,result_create) if !result_create.nil?
              if (!result_apply.nil?)
                muf_login.clear
                muf_login.reset_muf
              end
              muf_login
            elsif (muf_login.changed?)
              @@log.info "Changing muf definition for login: #{muf_login.login} muf:#{muf_login.user_muf_url}"
              result = muf_project.create_update_filter(muf_login.login,muf_login.get_gooddata_representation(muf_project.pid),muf_login.user_muf_url)
              if (!result.nil?)
                muf_login.clear
                muf_login.reset_muf
              end
              muf_login
            elsif (muf_login.to_delete?)
              # Lets delete them muf
              @@log.info "Deleting muf definition for login: #{muf_login.login} url: #{muf_login.user_muf_url}"
              result_delete = muf_project.delete_filter(muf_login.user_muf_url)
              # End apply empty string
              @@log.info "Changing muf-login connection to empty for login: #{muf_login.login} url: #{muf_login.user_muf_url}"
              result_apply = muf_project.apply_filter(muf_login.login,"") if !result_delete.nil?
              nil
            else
              muf_login.clear
              muf_login.reset_muf
              muf_login
            end
          end
        rescue => e
          @@log.error "The MUF process has failed"
          @@log.error e.message
        ensure
          Persistent.store_mufs(muf_project)
        end
      end

    end



    def load_mufs_from_gooddata()
      items = {}
      Persistent.project_data.find_all{|project| project.status == ProjectData.OK}.each do |project|
        finished = false
        muf_project = MufProject.new(project.ident,project.project_pid)
        while (!finished)
          offset = 0
          count = 100
          muf_structure = GoodData.get("/gdc/md/#{project.project_pid}/userfilters?count=#{count}&offset=#{offset}")
          finished = true if offset + count > muf_structure["userFilters"]["length"]
          muf_structure["userFilters"]["items"].each do |item|
            user_data = Persistent.get_user_by_profile_id(item["user"])
            if (!user_data.nil?)
              muf_login = MufLogin.new(user_data.login,item["user"])
              in_muf_count = 0
              item["userFilters"].each do |user_filter|
                user_definition_filter = GoodData.get(user_filter)
                expression = user_definition_filter["userFilter"]["content"]["expression"]
                title = user_definition_filter["userFilter"]["meta"]["title"]
                expressions = expression.split("AND")
                expressions.each do |expression_element|
                  expression_element.strip!
                  if (expression_element =~ /OVER/ )
                    match = expression_element.match(/^\(\[(?<attribute>[^\]]*)\]=\[(?<attribute_value>[^\]]*)\]\)[\s]*OVER[\s]*\[(?<cp_of_access_dt>[^\]]*)\][\s]*TO[\s]*\[(?<cp_of_filtered_dt>[^\]]*)\]/)
                    attribute_id = match[:attribute].split("/").last
                    attribute_value = match[:attribute_value]
                    cp_of_access_dt = match[:cp_of_access_dt].split("/").last
                    cp_of_filtered_dt = match[:cp_of_filtered_dt].split("/").last
                    muf = MufOver.new(attribute_id,user_filter,cp_of_access_dt,cp_of_filtered_dt)
                    muf.add_value(attribute_value,nil)
                    muf_login.add_muf(muf)
                  else
                    if (expression_element != Settings.deployment_mufs_empty_value)
                      fail "The PBH helper is supporting only one IN muf for user" if in_muf_count > 1
                      match = expression_element.match(/^\[(?<attribute>[^\s]*)\][^\[]*IN[^\[]*(?<elements>[^\s]*)\)/)
                      attribute_id = match[:attribute].match(/[^\/]*$/)[0]
                      elements = match[:elements].gsub(/[\[\]]/,"").split(",")
                      muf = MufIn.new(attribute_id,user_filter)
                      elements.each do |element|
                        muf.add_value(element,nil)
                      end
                      muf_login.add_muf(muf)
                      in_muf_count += 1
                    end
                  end
                end
              end
              muf_project.add_login(muf_login)
            else
              @@log.warn "User #{item["user"]} is not in PBH internal storage"
            end
          end
          offset += count
        end
        Persistent.muf_projects.push(muf_project)
      end
    end


    def find_muf_project_by_pid(pid)
      Persistent.muf_projects.find{|p| p.pid == pid }
    end

  end
end