#! /usr/bin/env bash

# Fail hard and fast
set -eo pipefail

echo "Container build date: $(cat /etc/build-date)"
echo "HOSTNAME found: $(hostname)"

# - Evaluate commands - 
# Any environment variable starting with KAFKA_ and ending with _COMMAND will be first evaluated
# and the result saved in an environment variable without the trailing _COMMAND
# For example an environment variable KAFKA_ADVERTISED_HOST_NAME_COMMAND=hostname will export 
# KAFKA_ADVERTISED_HOST_NAME with the value obtained by running hostname command inside the container

for VAR in $(env)
do
  if [[ $VAR =~ ^KAFKA_.*_COMMAND= ]]; then
    VAR_NAME=${VAR%%=*}
    EVALUATED_VALUE=$(eval ${!VAR_NAME})
    export ${VAR_NAME%_COMMAND}=${EVALUATED_VALUE}
    echo "${VAR} -> ${VAR_NAME%_COMMAND}=${EVALUATED_VALUE}"
  fi
done

if [ -z "$KAFKA_ZOOKEEPER_CONNECT" ]; then
  echo "\$KAFKA_ZOOKEEPER_CONNECT not set"
  exit 1
fi
echo "KAFKA_ZOOKEEPER_CONNECT=$KAFKA_ZOOKEEPER_CONNECT"

KAFKA_LOCK_FILE="/var/lib/kafka/.lock"
if [ -e "${KAFKA_LOCK_FILE}" ]; then
  echo "removing stale lock file"
  rm ${KAFKA_LOCK_FILE}
fi

export KAFKA_LOG_DIRS=${KAFKA_LOG_DIRS:-/var/lib/kafka}
export KAFKA_BROKER_ID=${KAFKA_BROKER_ID:-FALSE}

# Input new line to not break on concat
echo "" >> $KAFKA_HOME/config/server.properties

# - Tidy Up Default Parameters -
# broker.id - Check if we are to use auto_generated broker ids
if [[ "$KAFKA_BROKER_ID" == "FALSE" ]]; then
  echo "No KAFKA_BROKER_ID found - using auto_generated_id"
  # Enable auto broker ids by commenting it out
  sed -i "s/^broker\.id=0/#broker\.id=0/g" $KAFKA_HOME/config/server.properties
  # Unset the variable so we dont create broker.id=FALSE
  unset KAFKA_BROKER_ID
else
  echo "KAFKA_BROKER_ID found - using id: $KAFKA_BROKER_ID"
  # Change the default setting
  sed -i "s/^broker\.id=0/broker\.id=$KAFKA_BROKER_ID/g" $KAFKA_HOME/config/server.properties
  # Unset it as to not create twice
  unset KAFKA_BROKER_ID
fi  

# offsets.topic.replication.factor
if [[ "$KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR" != "" ]]; then
  # If SET then
 sed -i "s/^offsets\.topic\.replication\.factor=1/offsets\.topic\.replication\.factor=$KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR/g" \
   $KAFKA_HOME/config/server.properties
  # Unset it as to not create twice
  unset KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR
fi

# transaction.state.log.replication.factor
if [[ "$KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR" != "" ]]; then
  # If SET then
  sed -i "s/^transaction\.state\.log\.replication\.factor=1/transaction\.state\.log\.replication\.factor=$KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR/g" \
    $KAFKA_HOME/config/server.properties
  # Unset it as to not create twice
  unset KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR
fi

# transaction.state.log.min.isr
if [[ "$KAFKA_TRANSACTION_STATE_LOG_MIN_ISR" != "" ]]; then
  # If SET then
  sed -i "s/^transaction\.state\.log\.min\.isr=1/transaction\.state\.log\.min\.isr=$KAFKA_TRANSACTION_STATE_LOG_MIN_ISR/g" $KAFKA_HOME/config/server.properties
  # Unset it as to not create twice
  unset KAFKA_TRANSACTION_STATE_LOG_MIN_ISR
fi

# - General config -
# Configuration parameters can be provided via environment variables starting with KAFKA_ 
# Any matching variable will be added to Kafkas server.properties by removing the KAFKA_ prefix transformation 
# to lower case replacing any occurences of _ with .
# For example an environment variable KAFKA_NUM_PARTITIONS=3 will result in num.partitions=3 within server.properties

for VAR in `env`
do
  if [[ $VAR =~ ^KAFKA_ && ! $VAR =~ ^KAFKA_HOME ]]; then
    KAFKA_CONFIG_VAR=$(echo "$VAR" | sed -r "s/KAFKA_(.*)=.*/\1/g" | tr '[:upper:]' '[:lower:]' | tr _ .)
    KAFKA_ENV_VAR=${VAR%%=*}

    if egrep -q "(^|^#)$KAFKA_CONFIG_VAR" $KAFKA_HOME/config/server.properties; then
      sed -r -i "s (^|^#)$KAFKA_CONFIG_VAR=.*$ $KAFKA_CONFIG_VAR=${!KAFKA_ENV_VAR} g" $KAFKA_HOME/config/server.properties
    else
      echo "$KAFKA_CONFIG_VAR=${!KAFKA_ENV_VAR}" >> $KAFKA_HOME/config/server.properties
    fi
  fi
done

# Logging config
sed -i "s/^kafka\.logs\.dir=.*$/kafka\.logs\.dir=\/var\/log\/kafka/" /opt/kafka/config/log4j.properties
export LOG_DIR=/var/log/kafka

su kafka -s /bin/bash -c "cd /opt/kafka && bin/kafka-server-start.sh config/server.properties"
