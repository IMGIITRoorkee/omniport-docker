# RabbitMQ

Docker service name: `message-broker`

Running applications:
- `RabbitMQ`

Folder contents:
- `message_broker_stencil.env`: The fields in this file are to be populated to create the actual environment file, named `message_broker.env`.

## Description

The message queuing system used by Omniport is `RabbitMQ`. Since the image is directly used without building on top of it, no Dockerfile is required.

`RabbitMQ` may either be used standalone or in conjunction with a wrapper such as Celery in order to carry out long operations outside the request-response cycle in an asynchronous, non-blocking fashion.