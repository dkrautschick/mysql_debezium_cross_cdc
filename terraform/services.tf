data "aiven_project" "project" {
  project = var.project_name
}


##########################################################################################

# MySQL service
resource "aiven_mysql" "mysql-1" {
  project                 = var.project_name
  cloud_name              = "azure-switzerland-north"
  plan                    = "startup-4"
  service_name            = "mysql-1"

  mysql_user_config {
    mysql_version = 8

    mysql {
      sql_mode                = "ANSI,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION,NO_ZERO_DATE,NO_ZERO_IN_DATE"
      sql_require_primary_key = true
    }

    public_access {
      mysql = true
    }
  }
}

# Send metrics from MySQL to Thanos
resource "aiven_service_integration" "mysql-1-metrics" {
  project                  = var.project_name
  integration_type         = "metrics"
  source_service_name      = aiven_mysql.mysql-1.service_name
  destination_service_name = aiven_thanos.thanos.service_name
}

# Send logs from MySQL to Kafka
resource "aiven_service_integration" "mysql-1-logs-kafka" {
  project                  = var.project_name
  integration_type         = "kafka_logs"
  source_service_name      = aiven_mysql.mysql-1.service_name
  destination_service_name = aiven_kafka.kafka.service_name

  kafka_logs_user_config{
    kafka_topic = "mysql-1_logs"
  }
}


##########################################################################################

# MySQL service
resource "aiven_mysql" "mysql-2" {
  project                 = var.project_name
  cloud_name              = "azure-switzerland-north"
  plan                    = "startup-4"
  service_name            = "mysql-2"

  mysql_user_config {
    mysql_version = 8

    mysql {
      sql_mode                = "ANSI,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION,NO_ZERO_DATE,NO_ZERO_IN_DATE"
      sql_require_primary_key = true
    }

    public_access {
      mysql = true
    }
  }
}

# Send metrics from MySQL to Thanos
resource "aiven_service_integration" "mysql-2-metrics" {
  project                  = var.project_name
  integration_type         = "metrics"
  source_service_name      = aiven_mysql.mysql-2.service_name
  destination_service_name = aiven_thanos.thanos.service_name
}

# Send logs from MySQL to Kafka
resource "aiven_service_integration" "mysql-2-logs-kafka" {
  project                  = var.project_name
  integration_type         = "kafka_logs"
  source_service_name      = aiven_mysql.mysql-2.service_name
  destination_service_name = aiven_kafka.kafka.service_name

  kafka_logs_user_config{
    kafka_topic = "mysql-2_logs"
  }
}


##########################################################################################
# Kafka service
resource "aiven_kafka" "kafka" {
  project                 =  var.project_name
  cloud_name              = "azure-switzerland-north"
  plan                    = "startup-2"
  service_name            = "kafka"
  maintenance_window_dow  = "monday"
  maintenance_window_time = "10:00:00"

  kafka_user_config {
    kafka_rest      = true
    kafka_connect   = false
    schema_registry = true
    kafka_version   = "3.8"

    kafka {
      group_max_session_timeout_ms = 70000
      log_retention_bytes          = 1000000000
      num_partitions               = 3
      default_replication_factor   = 2
      min_insync_replicas          = 2      
      auto_create_topics_enable    = true
    }

    public_access {
      kafka_rest    = true
      kafka_connect = true
    }
  }
}

# Send metrics from Kafka to Thanos
resource "aiven_service_integration" "kafka-metrics" {
  project                  = var.project_name
  integration_type         = "metrics"
  source_service_name      = aiven_kafka.kafka.service_name
  destination_service_name = aiven_thanos.thanos.service_name
}
# Send logs from Kafka to Kafka
resource "aiven_service_integration" "kafka-logs-kafka" {
  project                  = var.project_name
  integration_type         = "kafka_logs"
  source_service_name      = aiven_kafka.kafka.service_name
  destination_service_name = aiven_kafka.kafka.service_name

  kafka_logs_user_config{
    kafka_topic = "kafka_logs"
  }

}

##########################################################################################

# Kafka Connect service
resource "aiven_kafka_connect" "kafka-connect-demo" {
  project                 = var.project_name
  cloud_name              = "azure-switzerland-north"
  plan                    = "startup-4"
  service_name            = "kafka-connect-demo"

  kafka_connect_user_config {
    kafka_connect {
      consumer_isolation_level = "read_committed"
    }

    public_access {
      kafka_connect = false
    }
  }
}

resource "aiven_service_integration" "i1" {
  project                  = var.project_name
  integration_type         = "kafka_connect"
  source_service_name      = aiven_kafka.kafka.service_name
  destination_service_name = aiven_kafka_connect.kafka-connect-demo.service_name

  kafka_connect_user_config {
    kafka_connect {
      group_id             = "connect"
      status_storage_topic = "__connect_status"
      offset_storage_topic = "__connect_offsets"
    }
  }
}

resource "aiven_kafka_connector" "debezium-source-mysql-1" {
  project        = var.project_name
  service_name   = aiven_kafka_connect.kafka-connect-demo.service_name
  connector_name = "debezium-source-mysql-1"

  config = {
    "name"                        = "debezium-source-mysql-1"
    "connector.class"             = "io.debezium.connector.mysql.MySqlConnector"
    "snapshot.mode"               = "initial"
    "database.hostname"           = sensitive(aiven_mysql.mysql-1.service_host)
    "database.port"               = sensitive(aiven_mysql.mysql-1.service_port)
    "database.password"           = sensitive(aiven_mysql.mysql-1.service_password)
    "database.user"               = sensitive(aiven_mysql.mysql-1.service_username)
    "database.dbname"             = "defaultdb"
    "database.server.name"        = "source-mysql-1"
    "database.server.id"          = 1      
    "database.ssl.mode"           = "required"
    "include.schema.changes"      = true
    "include.query"               = true
    "plugin.name"                 = "pgoutput"
    "topic.prefix"                = "mysql-1_"
    "tombstones.on.delete"        = true
    "publication.autocreate.mode" = "all_tables"
    "decimal.handling.mode"       = "double"
    "_aiven.restart.on.failure"   = "true"
    "heartbeat.interval.ms"       = 30000
    "heartbeat.action.query"      = "INSERT INTO heartbeat (status) VALUES (1)"
  }
  depends_on = [aiven_service_integration.i1]
}

resource "aiven_kafka_connector" "jdbc-sink-mysql-2" {
  project        = var.project_name
  service_name   = aiven_kafka_connect.kafka-connect-demo.service_name
  connector_name = "jdbc-sink-mysql-2"

  config = {
    "name"                                                  = "jdbc-sink-mysql-2"
    "connector.class"                                       = "io.aiven.connect.jdbc.JdbcSinkConnector"
    "topics"                                                = "source-mysql-1.*"
    "connection.url"                                        = sensitive(aiven_mysql.mysql-1.service_uri)
    "connection.user"                                       = sensitive(aiven_mysql.mysql-2.service_username)
    "connection.password"                                   = sensitive(aiven_mysql.mysql-2.service_password)
    "insert.mode"                                           = "upsert"
    "pk.mode"                                               = "record_key"
    "pk.fields"                                             = "name"
    "auto.create"                                           = "true"
    "transforms"                                            = "newrecordstate"
    "transforms.newrecordstate.type"                        = "io.debezium.transforms.ExtractNewRecordState"
    "transforms.newrecordstate.drop.tombstones"             = "false"
    "transforms.newrecordstate.delete.handling.mode"        = "rewrite"
    "key.converter"                                         = "io.confluent.connect.avro.AvroConverter"
    "key.converter.schema.registry.url"                     = sensitive(aiven_kafka.kafka.service_uri)
    "key.converter.basic.auth.credentials.source"           = "USER_INFO"
    "key.converter.schema.registry.basic.auth.user.info"    = "SCHEMA_REGISTRY_USERNAME:PASSWORD"
    "value.converter"                                       = "io.confluent.connect.avro.AvroConverter"
    "value.converter.schema.registry.url"                   = sensitive(aiven_kafka.kafka.service_uri)
    "value.converter.basic.auth.credentials.source"         = "USER_INFO"
    "value.converter.schema.registry.basic.auth.user.info"  = "SCHEMA_REGISTRY_USERNAME:PASSWORD"
  }
  depends_on = [aiven_service_integration.i1]
}


resource "aiven_kafka_connector" "debezium-source-mysql-2" {
  project        = var.project_name
  service_name   = aiven_kafka_connect.kafka-connect-demo.service_name
  connector_name = "debezium-source-mysql-2"

  config = {
    "name"                        = "debezium-source-mysql-2"
    "connector.class"             = "io.debezium.connector.mysql.MySqlConnector"
    "snapshot.mode"               = "initial"
    "database.hostname"           = sensitive(aiven_mysql.mysql-2.service_host)
    "database.port"               = sensitive(aiven_mysql.mysql-2.service_port)
    "database.password"           = sensitive(aiven_mysql.mysql-2.service_password)
    "database.user"               = sensitive(aiven_mysql.mysql-2.service_username)
    "database.dbname"             = "defaultdb"
    "database.server.name"        = "source-mysql-2"
    "database.server.id"          = 2    
    "database.ssl.mode"           = "required"
    "include.schema.changes"      = true
    "include.query"               = true
    "plugin.name"                 = "pgoutput"
    "topic.prefix"                = "mysql-2_"
    "tombstones.on.delete"        = true
    "publication.autocreate.mode" = "all_tables"
    "decimal.handling.mode"       = "double"
    "_aiven.restart.on.failure"   = "true"
    "heartbeat.interval.ms"       = 30000
    "heartbeat.action.query"      = "INSERT INTO heartbeat (status) VALUES (1)"
  }
  depends_on = [aiven_service_integration.i1]
}

resource "aiven_kafka_connector" "jdbc-sink-mysql-1" {
  project        = var.project_name
  service_name   = aiven_kafka_connect.kafka-connect-demo.service_name
  connector_name = "jdbc-sink-mysql-1"

  config = {
    "name"                                                  = "jdbc-sink-mysql-1"
    "connector.class"                                       = "io.aiven.connect.jdbc.JdbcSinkConnector"
    "topics"                                                = "source-mysql-2.*"
    "connection.url"                                        = sensitive(aiven_mysql.mysql-1.service_uri)
    "connection.user"                                       = sensitive(aiven_mysql.mysql-1.service_username)
    "connection.password"                                   = sensitive(aiven_mysql.mysql-1.service_password)
    "insert.mode"                                           = "upsert"
    "pk.mode"                                               = "record_key"
    "pk.fields"                                             = "name"
    "auto.create"                                           = "true"
    "transforms"                                            = "newrecordstate"
    "transforms.newrecordstate.type"                        = "io.debezium.transforms.ExtractNewRecordState"
    "transforms.newrecordstate.drop.tombstones"             = "false"
    "transforms.newrecordstate.delete.handling.mode"        = "rewrite"
    "key.converter"                                         = "io.confluent.connect.avro.AvroConverter"
    "key.converter.schema.registry.url"                     = sensitive(aiven_kafka.kafka.service_uri)
    "key.converter.basic.auth.credentials.source"           = "USER_INFO"
    "key.converter.schema.registry.basic.auth.user.info"    = "SCHEMA_REGISTRY_USERNAME:PASSWORD"
    "value.converter"                                       = "io.confluent.connect.avro.AvroConverter"
    "value.converter.schema.registry.url"                   = sensitive(aiven_kafka.kafka.service_uri)
    "value.converter.basic.auth.credentials.source"         = "USER_INFO"
    "value.converter.schema.registry.basic.auth.user.info"  = "SCHEMA_REGISTRY_USERNAME:PASSWORD"
  }
  depends_on = [aiven_service_integration.i1]
}

# Send metrics from Kafka Connect to Thanos
resource "aiven_service_integration" "kafka-connect-demo-metrics" {
  project                  = var.project_name
  integration_type         = "metrics"
  source_service_name      = aiven_kafka_connect.kafka-connect-demo.service_name
  destination_service_name = aiven_thanos.thanos.service_name
}
# Send logs from Kafka Connect to Kafka
resource "aiven_service_integration" "kafka-connect-demo-logs-kafka" {
  project                  = var.project_name
  integration_type         = "kafka_logs"
  source_service_name      = aiven_kafka_connect.kafka-connect-demo.service_name
  destination_service_name = aiven_kafka.kafka.service_name

  kafka_logs_user_config{
    kafka_topic = "kafka-connect-demo_logs"
  }

}

##########################################################################################

# Thanos service
resource "aiven_thanos" "thanos" {
  project                 = var.project_name
  cloud_name              = "azure-switzerland-north"
  plan                    = "startup-4"
  service_name            = "thanos"
}

# Send metrics from Thanos to Thanos
resource "aiven_service_integration" "thanos-metrics" {
  project                  = var.project_name
  integration_type         = "metrics"
  source_service_name      = aiven_thanos.thanos.service_name
  destination_service_name = aiven_thanos.thanos.service_name
}
# Send logs from Thanos to Kafka
resource "aiven_service_integration" "thanos-logs-kafka" {
  project                  = var.project_name
  integration_type         = "kafka_logs"
  source_service_name      = aiven_thanos.thanos.service_name
  destination_service_name = aiven_kafka.kafka.service_name

  kafka_logs_user_config{
    kafka_topic = "thanos_logs"
  }

}

##########################################################################################

# Grafana service
resource "aiven_grafana" "grafana" {
  project      = var.project_name
  cloud_name              = "azure-switzerland-north"
  plan                    = "startup-4"
  service_name = "grafana"
}

# Send logs from Grafana to Kafka
resource "aiven_service_integration" "grafana-logs-kafka" {
  project                  = var.project_name
  integration_type         = "kafka_logs"
  source_service_name      = aiven_grafana.grafana.service_name
  destination_service_name = aiven_kafka.kafka.service_name

  kafka_logs_user_config{
    kafka_topic = "grafana_logs"
  }
}

# Dashboards for all services by Thanos
resource "aiven_service_integration" "grafana-dashboards" {
  project                  = var.project_name
  integration_type         = "dashboard"
  source_service_name      = aiven_grafana.grafana.service_name
  destination_service_name = aiven_thanos.thanos.service_name
}