# mysql_debezium_cross_cdc

## terraform

just clone this repo and go in the terraform folder, then
create a project and token like

https://aiven.io/docs/platform/howto/manage-project

and

https://aiven.io/docs/platform/howto/create_authentication_token

enter project name and token in the file

terrafrom.tfvars

and force

a)
terraform init

b)
terraform plan

c)
terraform apply --auto-approve

## cli

Based on the 2 blog post the plan is to create a similar project
with Aiven CLI only.


https://aiven.io/developer/db-technology-migration-with-apache-kafka-and-kafka-connect
https://aiven.io/developer/change-data-capture-mysql-apache-kafka-debezium


In the folder avncli there are copys from the listings from the blog
post but not ready, tested or something else....will follow up on this.