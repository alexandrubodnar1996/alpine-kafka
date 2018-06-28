[![Docker Stars](https://img.shields.io/docker/stars/digitalwonderland/kafka.svg)](https://hub.docker.com/r/digitalwonderland/kafka/) [![Docker Pulls](https://img.shields.io/docker/pulls/digitalwonderland/kafka.svg)](https://hub.docker.com/r/digitalwonderland/kafka/) [![](https://images.microbadger.com/badges/image/digitalwonderland/kafka.svg)](https://microbadger.com/images/digitalwonderland/kafka)

# About:

[Docker](http://www.docker.com/) image based on [openjdk:8-jre-alpine](https://github.com/docker-library/openjdk/blob/master/8-jre/alpine/Dockerfile)

# Additional Software:

* [Apache Kafka](http://kafka.apache.org/)

# Usage:

The image provides a clusterable Kafka broker.

As a minimum the following environment variables must be set:

1. ```KAFKA_ZOOKEEPER_CONNECT```


```
docker run -d -e KAFKA_ZOOKEEPER_CONNECT=zk.zookeeper digitalwonderland/kafka
```

(if you are looking for a clusterable Zookeeper Docker image, feel free to use [digitalwonderland/zookeeper](https://github.com/digital-wonderland/docker-zookeeper))

### Additional Configuration

Configuration parameters can be provided via environment variables starting with ```KAFKA_```. Any matching variable will be added to Kafkas ```server.properties``` by

1. removing the ```KAFKA_``` prefix
2. transformation to lower case
3. replacing any occurences of ```_``` with ```.```

For example an environment variable ```KAFKA_NUM_PARTITIONS=3``` will result in ```num.partitions=3``` within ```server.properties```.

### Evaluated Parameters

Any environment variable starting with ```KAFKA_``` and ending with ```_COMMAND``` will be first evaluated and the result saved in an environment variable without the trailing ```_COMMAND```.

For example an environment variable ```KAFKA_ADVERTISED_HOST_NAME_COMMAND=hostname``` will export ```KAFKA_ADVERTISED_HOST_NAME``` with the value obtained by running ```hostname``` command inside the container.
