/*
Copyright (c) 2009-2018 Roger Light <roger@atchoo.org>

All rights reserved. This program and the accompanying materials
are made available under the terms of the Eclipse Public License v1.0
and Eclipse Distribution License v1.0 which accompany this distribution.

The Eclipse Public License is available at
   http://www.eclipse.org/legal/epl-v10.html
and the Eclipse Distribution License is available at
  http://www.eclipse.org/org/documents/edl-v10.php.

Contributors:
   Roger Light - initial implementation and documentation.
*/

#include <stdio.h>
#include <string.h>

#include "config.h"

#include "mosquitto_broker_internal.h"
#include "memory_mosq.h"
#include "mqtt3_protocol.h"
#include "packet_mosq.h"
#include "send_mosq.h"
/*
#include "sys_tree.h"
#include "time_mosq.h"
#include "tls_mosq.h"
#include "util_mosq.h"
*/

int handle__unsubscribe(struct mosquitto_db *db, struct mosquitto *context)
{
	uint16_t mid;
	char *sub;
	int slen;

	if(!context) return MOSQ_ERR_INVAL;
	log__printf(NULL, MOSQ_LOG_DEBUG, "Received UNSUBSCRIBE from %s", context->id);

	if(context->protocol == mosq_p_mqtt311){
		if((context->in_packet.command&0x0F) != 0x02){
			return MOSQ_ERR_PROTOCOL;
		}
	}
	if(packet__read_uint16(&context->in_packet, &mid)) return 1;

	if(context->protocol == mosq_p_mqtt311){
		if(context->in_packet.pos == context->in_packet.remaining_length){
			/* No topic specified, protocol error. */
			return MOSQ_ERR_PROTOCOL;
		}
	}
	while(context->in_packet.pos < context->in_packet.remaining_length){
		sub = NULL;
		if(packet__read_string(&context->in_packet, &sub, &slen)){
			return 1;
		}

		if(sub){
			if(!slen){
				log__printf(NULL, MOSQ_LOG_INFO,
						"Empty unsubscription string from %s, disconnecting.",
						context->id);
				mosquitto__free(sub);
				return 1;
			}
			if(mosquitto_sub_topic_check(sub)){
				log__printf(NULL, MOSQ_LOG_INFO,
						"Invalid unsubscription string from %s, disconnecting.",
						context->id);
				mosquitto__free(sub);
				return 1;
			}
			if(mosquitto_validate_utf8(sub, slen)){
				log__printf(NULL, MOSQ_LOG_INFO,
						"Malformed UTF-8 in unsubscription string from %s, disconnecting.",
						context->id);
				mosquitto__free(sub);
				return 1;
			}

			log__printf(NULL, MOSQ_LOG_DEBUG, "\t%s", sub);
			sub__remove(db, context, sub, db->subs);
			log__printf(NULL, MOSQ_LOG_UNSUBSCRIBE, "%s %s", context->id, sub);
			mosquitto__free(sub);
		}
	}
#ifdef WITH_PERSISTENCE
	db->persistence_changes++;
#endif

	return send__command_with_mid(context, UNSUBACK, mid, false);
}

