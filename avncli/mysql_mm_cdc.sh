avn service create demo-mysql-source    \
    --service-type mysql                \
    --plan startup-4                    \
    --cloud do-ams

avn service create demo-mysql-target    \
    --service-type mysql                \
    --plan startup-4                    \
    --cloud do-ams

 avn service create demo-kafka           \
    --service-type kafka                \
    --plan business-4                   \
    --cloud do-ams                      \
    -c kafka_connect=true               \
    -c schema_registry=true             \
    -c kafka.auto_create_topics_enable=true   

avn service wait demo-mysql-source
avn service wait demo-kafka

avn service get demo-mysql-source --format '{service_uri_params}'


mysql --user <MYSQL_USERNAME>           \
    --password=<MYSQL_PASSWORD>         \
    --host <MYSQL_HOSTNAME>             \
    --port <MYSQL_PORT>                 \
    <MYSQL_DATABASE_NAME>


create table users (id serial primary key, payload varchar(100));
insert into users (payload) values ('data1'),('data2'),('data3');

select * from users;


avn service get demo-mysql-source --format '{service_uri_params}'


avn service get demo-kafka --json | jq '.connection_info.schema_registry_uri'

avn service get demo-kafka --format '{service_uri}'


avn service connector create demo-kafka @mysql_source_deb_connector_kuk.json

avn service connector status demo-kafka mysql_source_deb_connector

avn service connection-info kcat demo-kafka -u avnadmin -W



kcat -b <KAFKA_HOST>:<KAFKA_PORT>               \
    -X security.protocol=SSL                    \
    -X ssl.ca.location=ca.pem                   \
    -X ssl.key.location=service.key             \
    -X ssl.certificate.location=service.crt     \
    -C -t mysql_source.defaultdb.users          \
    -s avro                                     \
    -r https://<KAFKA_SCHEMA_REGISTRY_USR>:<KAFKA_SCHEMA_REGISTRY_PWD>@<KAFKA_HOST>:<KAFKA_SCHEMA_REGISTRY_PORT>