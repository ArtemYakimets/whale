import pulsar

client = pulsar.Client('pulsar://192.168.56.10:6650')
consumer = client.subscribe('my-topic', 'my-subscription')

while True:
    msg = consumer.receive()
    try:
        print("Received message '{}' id='{}'".format(msg.data().decode('utf-8'), msg.message_id()))
        consumer.acknowledge(msg)
    except Exception:
        consumer.negative_acknowledge(msg)

client.close()
