#!/usr/bin/env python

# Test whether a PUBLISH to a topic with QoS 1 results in the correct PUBACK packet.

import inspect, os, sys
# From http://stackoverflow.com/questions/279237/python-import-a-module-from-a-folder
cmd_subfolder = os.path.realpath(os.path.abspath(os.path.join(os.path.split(inspect.getfile( inspect.currentframe() ))[0],"..")))
if cmd_subfolder not in sys.path:
    sys.path.insert(0, cmd_subfolder)

import mosq_test

rc = 1
mid = 19
keepalive = 60
connect_packet = mosq_test.gen_connect("pub-qos1-test", keepalive=keepalive)
connack_packet = mosq_test.gen_connack(rc=0)

publish_packet = mosq_test.gen_publish("pub/qos1/test", qos=1, mid=mid, payload="message")
puback_packet = mosq_test.gen_puback(mid)

port = mosq_test.get_port()
broker = mosq_test.start_broker(filename=os.path.basename(__file__), port=port)

try:
    sock = mosq_test.do_client_connect(connect_packet, connack_packet, port=port)
    sock.send(publish_packet)

    if mosq_test.expect_packet(sock, "puback", puback_packet):
        rc = 0

    sock.close()
finally:
    broker.terminate()
    broker.wait()
    (stdo, stde) = broker.communicate()
    if rc:
        print(stde)

exit(rc)

