#PoweredByHelper

##Description
The PoweredByHelper is tool create in Ruby, which should help you with provisioning of large numbers of projects. The source code of the tool can be found here: https://github.com/adriantoman/PoweredByHelper.

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

The tool is tested under ruby version 1.9.3, so you need to have this version of ruby installed on your computer (Tool should work also under other versions of ruby, but they are not tested). You also need rubygems tool installed.When you have all required prerequisites, run following set if commands:

##Instalation
```bash
git clone https://github.com/adriantoman/PoweredByHelper.git PoweredByHelper
cd PoweredByHelper
gem install bundler
bundle install
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

ETL
In this part of deployment section you can specify all settings needed for ETL scheduling and deployment. The possible settings are:

process (required)
source (required) - path to folder which contains graph folder with graphs, which need to be deployed on server. In most case scenario, it is link to CC project folder.
schedule (required) - section for schedules settings
graph_name (required) - name of the graph which need to be scheduled on platform
cron (required) - cron definition of time, when the project should be executed in UTC
parameters - section for normal schedule parameters. You can have more then one inner elemetns (more then one parameters)
name (required) - name of the parameter (if you specify the name as MODE, there will be some special rules applied on this parameter, more info below this section)
value (required) - value of the parameter
secure_parameters - section for secure parameters. You can have more then one inner elements here
name (required) - name of parameter
value (required) - value of parameter
        "process":{
            "source":"/home/adrian.toman/projects/ProvisioningTest/"
        },
		"schedule":  {
            "graph_name":"run.grf",
            "cron":"0 10 * * *",
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
        }
You can use special construction %ID% to add project_id to any parameter.

notifications - in this section you can specify multiple notification messages, which will be added to each schedule
type - the type of the event, on which the notification will react (success,error,schedule,start)
email -  email which should receive the notification
subject - notification subject
message - notification message
Example:

           "notifications":[
                {
                 "type":"success",
                 "email":"adrian.toman@gooddata.com",
                 "subject":"This is automatic notification",
                 "message":"The project has finished successfully"
                },
                {
                 "type":"failure",
                 "email":"adrian.toman@gooddata.com",
                 "subject":"This is automatic notification",
                 "message":"Please note that the \"Hodes\" project load ETL process (graph ${params.GRAPH}) that started at ${params.START_TIME} failed at ${params.FINISH_TIME} with following ERROR: \n ${params.ERROR_MESSAGE} \n Please inspect the ${params.LOG} for more details."
                }
            ]


User
The part of deployment section is used for enabling user provisioning. It consist of two distinguished part. Part for user domain creation and part for user-project mapping.

domain (required) - name of the Gooddata domain. User specified in connection section must be admin of this domain.
creation - user domain creation section
source (required) - path to user domain CSV file
mapping - mapping of fields from CSV file to internal PWH fields
login - user login (must be unique in domain). Most likely it will be user email adress
first_name - user first name
last_name - user last name
password - user password. In case when password is not specified, PWH will generate random password for the user.
super_admin (0/1) - sets if user is super admin. Super admin user will be invited to all project maintained by PWH tool. Please use wisely.
project_synchronization - user-project mapping section
source (required) -  path to user-project mapping CSV file
notification_message - this message will be part of the Gooddata user invite, which will be send to user after successful invitation to project.
mapping - mapping of fields from CSV file to internal PWH fields
ident - mapping to project identification field (this should correspond to ident in project file)
login - mapping to user login field
role - mapping to Gooddata role field (adminRole,connectorsSystemRole,editorRole,dashboardOnlyRole,unverifiedAdminRole,readOnlyUserRole)
notification (1/0) - mapping to notification field. If notification is enabled, user will receive Gooddata invitation mail, if it is disabled user will be automaticaly added to project.
internal_role (External/Internal) - mapping to internal role field. If the user is internal, he will have access to disabled projects. If the user is external, he will lose access to project after it is disabled.
Example:

        "user":{
            "domain" : "gooddata-adrian-toman",
            "creation":{
                "source": "config/users.csv",
                "mapping":{
                    "login":"login",
                    "first_name":"firstname",
                    "last_name":"lastname",
                    "password":"password",
                    "admin":"admin"
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
Execution
The execution part of the tools is quite strait forward. After you have successfully configured the application you can run it.

Dry run
The dry run will show you what will be done in standard run. You can executed it by following command executed in folder where you have installed provisioning tool:

ruby bin/poweredbyhelper dry_run --config=config/config.json
Provisioning
This command will start the provisioning. Tool will not start if there is other execution running. The messages about progress will be posted to console

ruby bin/poweredbyhelper provision --config=config/config.json





FAQ



