#PoweredByHelper

##Description
The PoweredByHelper is tool create in Ruby, which should help you with provisioning of large numbers of projects. The source code of the tool can be found here: https://github.com/adriantoman/PoweredByHelper.


## Status

[![Dependency Status](https://gemnasium.com/adriantoman/PoweredByHelper.png)](https://gemnasium.com/adriantoman/PoweredByHelper)
[![Code Climate](https://codeclimate.com/github/adriantoman/PoweredByHelper.png)](https://codeclimate.com/github/adriantoman/PoweredByHelper)
[![Build Status](https://travis-ci.org/adriantoman/PoweredByHelper.png)](https://travis-ci.org/adriantoman/PoweredByHelper)
[![Coverage Status](https://coveralls.io/repos/adriantoman/PoweredByHelper/badge.png)](https://coveralls.io/r/adriantoman/PoweredByHelper)
[![Build Status](https://travis-ci.org/adriantoman/PoweredByHelper.png)](https://travis-ci.org/adriantoman/PoweredByHelper)

##Currently supported features are:

* Project provisioning
* Project disabling/deleting
* ETL deployment
* ETL scheduling
* Notification creation
* Adding user to domain
* Inviting/Adding users to project
* Disabling users in project
* Changing user roles in project
* Installation
* MUF setting support

The tool is tested under ruby version 1.9.3, so you need to have this version of ruby installed on your computer (Tool should work also under other versions of ruby, but they are not tested). You also need rubygems tool installed.When you have all required prerequisites, run following set if commands:

##Instalation
```bash
git clone https://github.com/adriantoman/PoweredByHelper.git PoweredByHelper
cd PoweredByHelper
gem install bundler
bundle install --path gems
```
##Configuration
The tool configuration is done by one JSON file. The JSON file consist of few distinguish sections. Sections are: connection and deployment.

###Connection section
In the connection section you need to specify credentials for Gooddata servers. The possible settings are:

* **login** (required) - GoodData login (must be domain admin, if you want to use USER provisioning functionality)
* **password** (require) - Gooddata password
* server - GoodData server adress (default https://secure.gooddata.com)
* webdav - GoodData webdav adress (default https://secure-di.gooddata.com)

If you want to use other server then secure.gooddata.com, you must specify both server and webdav adress.

Example:
```json
    "connection":{
        "login": "adrian.toman+deploy_test@gooddata.com",
        "password": "password",
        "server": "https://secure.gooddata.com",
        "webdav": "https://secure-di.gooddata.com"
    }
```


###Deployment section
In the deployment section, you can specify settings needed for deployment to server. This section is divided to three separate parts. You don't need to use all three parts, but you always need to specify the Project part.

####Project
In this part of deployment section you need to specify information needed for project creation and maintenance. The possible settings are:

* **token** (requried) - GoodData project token
* **template** (required) - Location of project template. You can list all the templates here.
* delete - possible options here - disabled_users_first and force_delete. More info about this functionality is below the list.
* disable_duration - Duration in days, for how long project will be disabled before deletion.
* **data** (required) - Section for source data configuration
* **file_name** (required) - Path to source file with project provisioning data
* mapping - mapping of source file fields to PWH internal fields
* ident - unique project indetification field
* project_name - name of GoodData project

The delete options is quite important one. There are two possible setting and each represent special functionality:

* **force_delete** - when the project will disappear from project source file, it will be automacly deleted from Gooddata. This is ireversible action and all data and changes done in project will be lost. Please use this option with caution.
* **disabled_users_first** (default) - when the project disappear from the project source file, the tool will automaticaly disable all External users (more info about external users is in User part of Deployment section) in project. Project will be in this state for interval specified in disable_duration settings. After that period project will be deleted. This setting will not work in case, when you are not using project provisioning.

Example:
```json
"project":{
            "token": "TOKEN",
            "template":"/projectTemplates/PoweredbyDemo/1",
            "delete":"disable_users_first",
            "disable_duration":"30",
            "data":{
                "file_name":"config/data.csv",
                "mapping":{
                    "ident":"project_id",
                    "project_name":"field1"
                }
            }
        }
```        

####ETL
In this part of deployment section you can specify all settings needed for ETL scheduling and deployment. From version 0.2.0 it is possible to set multiple schedules. You can see the example in example_config.json. The possible settings are:

* **process** (required)
* **source** (required) - path to folder which contains graph folder with graphs, which need to be deployed on server. In most case scenario, it is link to CC project folder.
* **ident** (required when using multiple schedules) - this is identification of schedule. This is needed because you can create two different schedules on same time, same graph etc. This will differentiate between same schedules.
* **schedule** (required) - section for schedules settings
* **graph_name** (required) - name of the graph which need to be scheduled on platform
* **cron** (required) - cron definition of time, when the project should be executed in UTC
* **reschedule** (optional) - this will activate the reschedule feature on schedule (automatic restart)
* **force_execute** (true/false)(optional) - this will execute the schedule right after deployment or schedule update
* parameters - section for normal schedule parameters. You can have more then one inner elemetns (more then one parameters)
  * **name** (required) - name of the parameter (if you specify the name as MODE, there will be some special rules applied on this parameter, more info below this section)
  * **value** (required) - value of the parameter
* secure_parameters - section for secure parameters. You can have more then one inner elements here
  * **name** (required) - name of parameter
  * **value** (required) - value of parameter

Example:
```json
        "process":{
            "source":"/home/adrian.toman/projects/ProvisioningTest/"
        },
		"schedule":  [{
            "ident": "1",
            "graph_name":"run.grf",
            "cron":"0 10 * * *",
            "reschedule":15,
            "parameters":[
                {
                    "name":"MODE",
                    "value":"PRODUCTION/TWC/%ID%"
                }
            ],
            "secure_parameters":[
                {
                    "name":"PASSWORD",
                    "value":"SECRET"
                }
            ]
        }]
```        
You can use special construction %ID% to add project_id to any parameter or you can use %custom1%,%custom2% to use custom parameter from project source file.

* notifications - in this section you can specify multiple notification messages, which will be added to each schedule
* type - the type of the event, on which the notification will react (success,error,schedule,start)
* email -  email which should receive the notification
* subject - notification subject
* message - notification message

Example:

```json
           "notifications":[
                {
                 "type":"success",
                 "email":"adrian.toman@gooddata.com",
                 "subject":"This is automatic notification",
                 "message":"The project has finished successfully"
                },
                {
                 "type":"error",
                 "email":"adrian.toman@gooddata.com",
                 "subject":"This is automatic notification",
                 "message":"Please note that the \"Hodes\" project load ETL process (graph ${params.GRAPH}) that started at ${params.START_TIME} failed at ${params.FINISH_TIME} with following ERROR: \n ${params.ERROR_MESSAGE} \n Please inspect the ${params.LOG} for more details."
                }
            ]
```

####User
The part of deployment section is used for enabling user provisioning. It consist of two distinguished part. Part for user domain creation and part for user-project mapping.

* **domain** (required) - name of the Gooddata domain. User specified in connection section must be admin of this domain.
* creation - user domain creation section
  * **source** (required) - path to user domain CSV file
  * mapping - mapping of fields from CSV file to internal PWH fields
    * login - user login (must be unique in domain). Most likely it will be user email adress
    * first_name - user first name
    * last_name - user last name
    * password - user password. In case when password is not specified, PWH will generate random password for the user.
    * admin (0/1) - sets if user is super admin. Super admin user will be invited to all project maintained by PWH tool. Please use wisely.
    * sso_provider (optional) - set SSO Provider for each user

* project_synchronization - user-project mapping section
  * **source** (required) -  path to user-project mapping CSV file
  * notification_message - this message will be part of the Gooddata user invite, which will be send to user after successful invitation to project.
  * mapping - mapping of fields from CSV file to internal PWH fields
    * ident - mapping to project identification field (this should correspond to ident in project file)
    * login - mapping to user login field
    * role - mapping to Gooddata role field (adminRole,connectorsSystemRole,editorRole,dashboardOnlyRole,unverifiedAdminRole,readOnlyUserRole)
    * notification (1/0) - mapping to notification field. If notification is enabled, user will receive Gooddata invitation mail, if it is disabled user will be automaticaly added to project.
    * internal_role (External/Internal) - mapping to internal role field. If the user is internal, he will have access to disabled projects. If the user is external, he will lose access to project after it is disabled.

Example:

```json
        "user":{
            "domain" : "gooddata-adrian-toman",
            "creation":{
                "source": "config/users.csv",
                "mapping":{
                    "login":"login",
                    "first_name":"firstname",
                    "last_name":"lastname",
                    "password":"password",
                    "admin":"admin",
                    "sso_provider":"sso"
                }
            },
            "project_synchronization":{
                "source":"config/user_synchronization.csv",
                "mapping":{
                    "ident":"ID",
                    "login":"login",
                    "role":"gooddata_role",
                    "notification":"notification",
                    "internal_role":"internal_role"
                },
                "notification_message":"Welcome to new TWC project"
            }
        }
```

#### Mandatory user filters (MUFs)
This part of deployment section is used for enabling the Mandatory user filters. This is new feature implemented in version 0.3.0 of Powered By Helper tool. If you want to start with mandatory user filters,
     I strongly advice you to start in here: https://developer.gooddata.com/article/lets-get-started-with-mandatory-user-filters. The current implementation of PWB tool implements only the IN type of MUF.

The MUFs are configured by set of files, when each file represent the MUF setting for on particular project. Connection between project and muf file, is done by file_patter setting. In this setting
   you can specify the patter, by which the PBH will identify muf file for particular project.

So for example, when I have in file_patter setting this: mufs/muf_file_%ID%.csv and I have project Id: 0001, the PBH will be looking in folder mufs for file named muf_file_0001.csv. In file_patter you can use
 any of project specific custom parameters  (%custom1%,%custom2%,etc).

The MUF file, need to have specific format. It need to be CSV file. There need to be always column, which is containing user login name. It will also contain column, which is representing desired MUF value.

For example the CSV file could look like this:

```csv
"login","attribute1","attribute2"
"adrian.toman+testing1@gooddata.com","Karel","Zientek"
"adrian.toman+testing1@gooddata.com","Petr","Novak"
"adrian.toman+testing2@gooddata.com","Adrian","Novak"
"adrian.toman+testing2@gooddata.com","Petr","Tichy"
```

This file is representing setting for two mufs. It will set attribute1 and attribute2 (the attribute1 and attribute2 settings need to be present in config.json file) for specific logins. As you can see, you can
apply multiple values for one muf. In this example we are settings two MUFs for one login. Each row, represent one MUF value. If you don't have same number of MUF values for each attribute, you can use
the keyword "TRUE" (this can be changed by empty_value settings). The TRUE value is used as EMPTY value and I will not be used for MUF setting.

One of the key settings is cache settings. If this value is set to false, the PBH will download all existing MUF values from Gooddata and it will compare them to your current settings. The tool will do it
every time you execute the provisioning command. Sadly download of all mufs from platform, can be very time consuming task, so in case that you are not using the cache, you need to count with very long provisioning
runs. I always suggest that you used the false setting for first run of provisioning of MUFS. This way, if you have any mufs already set up in project, you can continue with current settings. Even if the setting is set to false,
the cache file is created, but it is not used. So if you use false settings at the beginning and after that you continue with true settings, everything should work fine. **If you are using the cache file, you cannot
use any other tool for muf settings.**


* **file_patter** (required) - the file patter for finding connection between project and muf file
* **user_id_field** (required) - the name of column in each of the muf files, which contains user login
* **empty_value** - (TRUE) - the substitution for empty value, because empty value is valid Gooddata value, so you need to use something which is not present in your dataset
* **type** - (local/webdav) - you can specify, if you want to download the files from webdav before each run
* **remote_dir** - this is the folder on webdav, in which the tooo will be searching for the pattern
* **source_dir** - this is the folder, when the tool will be looking for muf files. Also in case of webdav download, the files will be downloaded in to this folder
* **webdav_folder_target** - this is the folder, where the file will be moved after the successfull run

* **use_cache** (required) - (true/false) - this will enable or disable usage of cache files.
  * mufs - the section containing the definition of each specific muf
    * **attribute** - this field need to contain the ID of the attribute object (more info about this can be found in the article linked at the begining of the muf section)
    * **elemenets** - this field need to contain the ID of elements set, which contain values loaded in GD. This is here, because of attributes with different label. (more info about this can be found in the article linked at the begining of the muf section)
    * **csv_header** - this field need to contain the name of column in muf_file which will contain the values for muf.
    * **type** - this field has two possible values (in / over). The in is default value.
    * **connection_point_of_access_dataset** - this values is used only with over type of muf.
    * **connection_point_of_filtered_dataset** - this values is used only with over type of muf.

Example:
```json
      "mufs":{
                 "file_pattern":"mufs/muf_file_%ID%.csv",
                 "user_id_field":"login",
                 "empty_value":"TRUE",
                 "use_cache":true,
                 "muf":[
                     {
                         "attribute" : "904",
                         "elements" : "905",
                         "csv_header": "attribute1"
                     },
                     {
                         "attribute" : "906",
                         "elements" : "907",
                         "csv_header": "attribute2"
                     }

                 ]
             }
```             

##Execution
The execution part of the tools is quite strait forward. After you have successfully configured the application you can run it.


###Dry run
The dry run will show you what will be done in standard run. You can executed it by following command executed in folder where you have installed provisioning tool:

```bash
ruby bin/poweredbyhelper dry_run --config=config/config.json
```

In case that you are using webdav as a source, the dry_run command, will move the file on webdav from source folder to processing folder. In the next run, the files will be taken from processing folder,
instead of source folder. If you don't want to use files in processing folder, simply delete them.

###Provisioning

This command will start the provisioning. Tool will not start if there is other execution running. The messages about progress will be posted to console

```bash
ruby bin/poweredbyhelper provision --config=config/config.json
```

###Update schedule

This command will will update schedules for all provisioned projects, with settings from config.json file.

```bash
ruby bin/poweredbyhelper update_schedule --config=config/config.json
```

###Update process

This command will deploy new ETL to all provisioned projects. Process ID will stay the same.

```bash
ruby bin/poweredbyhelper update_process --config=config/config.json

```

###Execute maql

This command will execute maql on all projects provisioned by this tool

```bash
ruby bin/poweredbyhelper execute_maql --config=config/config.json --maql=config/maql.txt

```

###Execute Partial Metadata

This command will execute partial metadata import on all project provisioned by this tool.

```bash
ruby bin/poweredbyhelper execute_partial_metadata --config=config/config.json --token=export_token

```

More info about partial metadata import/export look here: [http://developer.gooddata.com/article/migrating-selected-objects-between-projects]


##FAQ



