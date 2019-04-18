/*
Copyright (c) 2011-2018 Roger Light <roger@atchoo.org>

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

#include "config.h"

#include <stdio.h>
#include <string.h>

#include "mosquitto_broker_internal.h"
#include "mosquitto_plugin.h"
#include "memory_mosq.h"
#include "lib_load.h"

typedef int (*FUNC_auth_plugin_version)(void);

static int security__cleanup_single(struct mosquitto__security_options *opts, bool reload);

void LIB_ERROR(void)
{
#ifdef WIN32
	char *buf;
	FormatMessage(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_STRING,
			NULL, GetLastError(), LANG_NEUTRAL, &buf, 0, NULL);
	log__printf(NULL, MOSQ_LOG_ERR, "Load error: %s", buf);
	LocalFree(buf);
#else
	log__printf(NULL, MOSQ_LOG_ERR, "Load error: %s", dlerror());
#endif
}


int security__load_v2(struct mosquitto_db *db, struct mosquitto__auth_plugin *plugin, struct mosquitto_auth_opt *auth_options, int auth_option_count, void *lib)
{
	int rc;

	if(!(plugin->plugin_init_v2 = (FUNC_auth_plugin_init_v2)LIB_SYM(lib, "mosquitto_auth_plugin_init"))){
		log__printf(NULL, MOSQ_LOG_ERR,
				"Error: Unable to load auth plugin function mosquitto_auth_plugin_init().");
		LIB_ERROR();
		LIB_CLOSE(lib);
		return 1;
	}
	if(!(plugin->plugin_cleanup_v2 = (FUNC_auth_plugin_cleanup_v2)LIB_SYM(lib, "mosquitto_auth_plugin_cleanup"))){
		log__printf(NULL, MOSQ_LOG_ERR,
				"Error: Unable to load auth plugin function mosquitto_auth_plugin_cleanup().");
		LIB_ERROR();
		LIB_CLOSE(lib);
		return 1;
	}

	if(!(plugin->security_init_v2 = (FUNC_auth_plugin_security_init_v2)LIB_SYM(lib, "mosquitto_auth_security_init"))){
		log__printf(NULL, MOSQ_LOG_ERR,
				"Error: Unable to load auth plugin function mosquitto_auth_security_init().");
		LIB_ERROR();
		LIB_CLOSE(lib);
		return 1;
	}

	if(!(plugin->security_cleanup_v2 = (FUNC_auth_plugin_security_cleanup_v2)LIB_SYM(lib, "mosquitto_auth_security_cleanup"))){
		log__printf(NULL, MOSQ_LOG_ERR,
				"Error: Unable to load auth plugin function mosquitto_auth_security_cleanup().");
		LIB_ERROR();
		LIB_CLOSE(lib);
		return 1;
	}

	if(!(plugin->acl_check_v2 = (FUNC_auth_plugin_acl_check_v2)LIB_SYM(lib, "mosquitto_auth_acl_check"))){
		log__printf(NULL, MOSQ_LOG_ERR,
				"Error: Unable to load auth plugin function mosquitto_auth_acl_check().");
		LIB_ERROR();
		LIB_CLOSE(lib);
		return 1;
	}

	if(!(plugin->unpwd_check_v2 = (FUNC_auth_plugin_unpwd_check_v2)LIB_SYM(lib, "mosquitto_auth_unpwd_check"))){
		log__printf(NULL, MOSQ_LOG_ERR,
				"Error: Unable to load auth plugin function mosquitto_auth_unpwd_check().");
		LIB_ERROR();
		LIB_CLOSE(lib);
		return 1;
	}

	if(!(plugin->psk_key_get_v2 = (FUNC_auth_plugin_psk_key_get_v2)LIB_SYM(lib, "mosquitto_auth_psk_key_get"))){
		log__printf(NULL, MOSQ_LOG_ERR,
				"Error: Unable to load auth plugin function mosquitto_auth_psk_key_get().");
		LIB_ERROR();
		LIB_CLOSE(lib);
		return 1;
	}

	plugin->lib = lib;
	plugin->user_data = NULL;

	if(plugin->plugin_init_v2){
		rc = plugin->plugin_init_v2(&plugin->user_data, auth_options, auth_option_count);
		if(rc){
			log__printf(NULL, MOSQ_LOG_ERR,
					"Error: Authentication plugin returned %d when initialising.", rc);
			return rc;
		}
	}
	return 0;
}


int security__load_v3(struct mosquitto_db *db, struct mosquitto__auth_plugin *plugin, struct mosquitto_opt *auth_options, int auth_option_count, void *lib)
{
	int rc;

	if(!(plugin->plugin_init_v3 = (FUNC_auth_plugin_init_v3)LIB_SYM(lib, "mosquitto_auth_plugin_init"))){
		log__printf(NULL, MOSQ_LOG_ERR,
				"Error: Unable to load auth plugin function mosquitto_auth_plugin_init().");
		LIB_ERROR();
		LIB_CLOSE(lib);
		return 1;
	}
	if(!(plugin->plugin_cleanup_v3 = (FUNC_auth_plugin_cleanup_v3)LIB_SYM(lib, "mosquitto_auth_plugin_cleanup"))){
		log__printf(NULL, MOSQ_LOG_ERR,
				"Error: Unable to load auth plugin function mosquitto_auth_plugin_cleanup().");
		LIB_ERROR();
		LIB_CLOSE(lib);
		return 1;
	}

	if(!(plugin->security_init_v3 = (FUNC_auth_plugin_security_init_v3)LIB_SYM(lib, "mosquitto_auth_security_init"))){
		log__printf(NULL, MOSQ_LOG_ERR,
				"Error: Unable to load auth plugin function mosquitto_auth_security_init().");
		LIB_ERROR();
		LIB_CLOSE(lib);
		return 1;
	}

	if(!(plugin->security_cleanup_v3 = (FUNC_auth_plugin_security_cleanup_v3)LIB_SYM(lib, "mosquitto_auth_security_cleanup"))){
		log__printf(NULL, MOSQ_LOG_ERR,
				"Error: Unable to load auth plugin function mosquitto_auth_security_cleanup().");
		LIB_ERROR();
		LIB_CLOSE(lib);
		return 1;
	}

	if(!(plugin->acl_check_v3 = (FUNC_auth_plugin_acl_check_v3)LIB_SYM(lib, "mosquitto_auth_acl_check"))){
		log__printf(NULL, MOSQ_LOG_ERR,
				"Error: Unable to load auth plugin function mosquitto_auth_acl_check().");
		LIB_ERROR();
		LIB_CLOSE(lib);
		return 1;
	}

	if(!(plugin->unpwd_check_v3 = (FUNC_auth_plugin_unpwd_check_v3)LIB_SYM(lib, "mosquitto_auth_unpwd_check"))){
		log__printf(NULL, MOSQ_LOG_ERR,
				"Error: Unable to load auth plugin function mosquitto_auth_unpwd_check().");
		LIB_ERROR();
		LIB_CLOSE(lib);
		return 1;
	}

	if(!(plugin->psk_key_get_v3 = (FUNC_auth_plugin_psk_key_get_v3)LIB_SYM(lib, "mosquitto_auth_psk_key_get"))){
		log__printf(NULL, MOSQ_LOG_ERR,
				"Error: Unable to load auth plugin function mosquitto_auth_psk_key_get().");
		LIB_ERROR();
		LIB_CLOSE(lib);
		return 1;
	}

	plugin->lib = lib;
	plugin->user_data = NULL;
	if(plugin->plugin_init_v3){
		rc = plugin->plugin_init_v3(&plugin->user_data, auth_options, auth_option_count);
		if(rc){
			log__printf(NULL, MOSQ_LOG_ERR,
					"Error: Authentication plugin returned %d when initialising.", rc);
			return rc;
		}
	}
	return 0;
}


static int security__module_init_single(struct mosquitto_db *db, struct mosquitto__security_options *opts)
{
	void *lib;
	int (*plugin_version)(void) = NULL;
	int version;
	int i;
	int rc;

	if(opts->auth_plugin_config_count == 0){
		return MOSQ_ERR_SUCCESS;
	}

	for(i=0; i<opts->auth_plugin_config_count; i++){
		if(opts->auth_plugin_configs[i].path){
			memset(&opts->auth_plugin_configs[i].plugin, 0, sizeof(struct mosquitto__auth_plugin));

			lib = LIB_LOAD(opts->auth_plugin_configs[i].path);
			if(!lib){
				log__printf(NULL, MOSQ_LOG_ERR,
						"Error: Unable to load auth plugin \"%s\".", opts->auth_plugin_configs[i].path);
				LIB_ERROR();
				return 1;
			}

			opts->auth_plugin_configs[i].plugin.lib = NULL;
			if(!(plugin_version = (FUNC_auth_plugin_version)LIB_SYM(lib, "mosquitto_auth_plugin_version"))){
				log__printf(NULL, MOSQ_LOG_ERR,
						"Error: Unable to load auth plugin function mosquitto_auth_plugin_version().");
				LIB_ERROR();
				LIB_CLOSE(lib);
				return 1;
			}
			version = plugin_version();
			opts->auth_plugin_configs[i].plugin.version = version;
			if(version == 3){
				rc = security__load_v3(
						db,
						&opts->auth_plugin_configs[i].plugin,
						opts->auth_plugin_configs[i].options,
						opts->auth_plugin_configs[i].option_count,
						lib);

				if(rc){
					return rc;
				}
			}else if(version == 2){
				rc = security__load_v2(
						db,
						&opts->auth_plugin_configs[i].plugin,
						(struct mosquitto_auth_opt *)opts->auth_plugin_configs[i].options,
						opts->auth_plugin_configs[i].option_count,
						lib);

				if(rc){
					return rc;
				}
			}else{
				log__printf(NULL, MOSQ_LOG_ERR,
						"Error: Incorrect auth plugin version (got %d, expected %d).",
						version, MOSQ_AUTH_PLUGIN_VERSION);
				LIB_ERROR();

				LIB_CLOSE(lib);
				return 1;
			}
		}
	}
	return MOSQ_ERR_SUCCESS;
}


int mosquitto_security_module_init(struct mosquitto_db *db)
{
	int rc = MOSQ_ERR_SUCCESS;
	int i;

	if(db->config->per_listener_settings){
		for(i=0; i<db->config->listener_count; i++){
			rc = security__module_init_single(db, &db->config->listeners[i].security_options);
			if(rc) return rc;
		}
	}else{
		rc = security__module_init_single(db, &db->config->security_options);
	}
	return rc;
}


static void security__module_cleanup_single(struct mosquitto__security_options *opts)
{
	int i;

	for(i=0; i<opts->auth_plugin_config_count; i++){
		if(opts->auth_plugin_configs[i].plugin.lib){
			LIB_CLOSE(opts->auth_plugin_configs[i].plugin.lib);
		}
		memset(&opts->auth_plugin_configs[i].plugin, 0, sizeof(struct mosquitto__auth_plugin));
	}
}


int mosquitto_security_module_cleanup(struct mosquitto_db *db)
{
	int i;

	mosquitto_security_cleanup(db, false);

	security__module_cleanup_single(&db->config->security_options);

	for(i=0; i<db->config->listener_count; i++){
		security__module_cleanup_single(&db->config->listeners[i].security_options);
	}

	return MOSQ_ERR_SUCCESS;
}


static int security__init_single(struct mosquitto__security_options *opts, bool reload)
{
	int i;
	int rc;

	for(i=0; i<opts->auth_plugin_config_count; i++){
		if(opts->auth_plugin_configs[i].plugin.version == 3){
			rc = opts->auth_plugin_configs[i].plugin.security_init_v3(
					opts->auth_plugin_configs[i].plugin.user_data,
					opts->auth_plugin_configs[i].options,
					opts->auth_plugin_configs[i].option_count,
					reload);

		}else if(opts->auth_plugin_configs[i].plugin.version == 2){
			rc = opts->auth_plugin_configs[i].plugin.security_init_v2(
					opts->auth_plugin_configs[i].plugin.user_data,
					(struct mosquitto_auth_opt *)opts->auth_plugin_configs[i].options,
					opts->auth_plugin_configs[i].option_count,
					reload);
		}else{
			rc = MOSQ_ERR_INVAL;
		}
		if(rc != MOSQ_ERR_SUCCESS){
			return rc;
		}
	}
	return MOSQ_ERR_SUCCESS;
}


int mosquitto_security_init(struct mosquitto_db *db, bool reload)
{
	int i;
	int rc;

	if(db->config->per_listener_settings){
		for(i=0; i<db->config->listener_count; i++){
			rc = security__init_single(&db->config->listeners[i].security_options, reload);
			if(rc != MOSQ_ERR_SUCCESS) return rc;
		}
	}else{
		rc = security__init_single(&db->config->security_options, reload);
		if(rc != MOSQ_ERR_SUCCESS) return rc;
	}
	return mosquitto_security_init_default(db, reload);
}

/* Apply security settings after a reload.
 * Includes:
 * - Disconnecting anonymous users if appropriate
 * - Disconnecting users with invalid passwords
 * - Reapplying ACLs
 */
int mosquitto_security_apply(struct mosquitto_db *db)
{
	return mosquitto_security_apply_default(db);
}


static int security__cleanup_single(struct mosquitto__security_options *opts, bool reload)
{
	int i;
	int rc;

	for(i=0; i<opts->auth_plugin_config_count; i++){
		if(opts->auth_plugin_configs[i].plugin.version == 3){
			rc = opts->auth_plugin_configs[i].plugin.security_cleanup_v3(
					opts->auth_plugin_configs[i].plugin.user_data,
					opts->auth_plugin_configs[i].options,
					opts->auth_plugin_configs[i].option_count,
					reload);

		}else if(opts->auth_plugin_configs[i].plugin.version == 2){
			rc = opts->auth_plugin_configs[i].plugin.security_cleanup_v2(
					opts->auth_plugin_configs[i].plugin.user_data,
					(struct mosquitto_auth_opt *)opts->auth_plugin_configs[i].options,
					opts->auth_plugin_configs[i].option_count,
					reload);
		}else{
			rc = MOSQ_ERR_INVAL;
		}
		if(rc != MOSQ_ERR_SUCCESS){
			return rc;
		}
	}

	return MOSQ_ERR_SUCCESS;
}


int mosquitto_security_cleanup(struct mosquitto_db *db, bool reload)
{
	int i;
	int rc;

	rc = security__cleanup_single(&db->config->security_options, reload);
	if(rc != MOSQ_ERR_SUCCESS) return rc;

	for(i=0; i<db->config->listener_count; i++){
		rc = security__cleanup_single(&db->config->listeners[i].security_options, reload);
		if(rc != MOSQ_ERR_SUCCESS) return rc;
	}
	return mosquitto_security_cleanup_default(db, reload);
}


//int mosquitto_acl_check(struct mosquitto_db *db, struct mosquitto *context, const char *topic, int access)
static int acl__check_single(struct mosquitto__auth_plugin_config *auth_plugin, struct mosquitto *context, const char *topic, int access)
{
	struct mosquitto_acl_msg msg;
	const char *username;

	memset(&msg, 0, sizeof(msg));
	msg.topic = topic;

	username = mosquitto_client_username(context);
	if(auth_plugin->deny_special_chars == true){
		/* Check whether the client id or username contains a +, # or / and if
		* so deny access.
		*
		* Do this check for every message regardless, we have to protect the
		* plugins against possible pattern based attacks.
		*/
		if(username && strpbrk(username, "+#")){
			log__printf(NULL, MOSQ_LOG_NOTICE, "ACL denying access to client with dangerous username \"%s\"", username);
			return MOSQ_ERR_ACL_DENIED;
		}
		if(context->id && strpbrk(context->id, "+#")){
			log__printf(NULL, MOSQ_LOG_NOTICE, "ACL denying access to client with dangerous client id \"%s\"", context->id);
			return MOSQ_ERR_ACL_DENIED;
		}
	}

	if(auth_plugin->plugin.version == 3){
		return auth_plugin->plugin.acl_check_v3(auth_plugin->plugin.user_data, access, context, &msg);
	}else if(auth_plugin->plugin.version == 2){
		if(access == MOSQ_ACL_SUBSCRIBE){
			return MOSQ_ERR_SUCCESS;
		}
		return auth_plugin->plugin.acl_check_v2(auth_plugin->plugin.user_data, context->id, username, topic, access);
	}else{
		return MOSQ_ERR_INVAL;
	}
}


int mosquitto_acl_check(struct mosquitto_db *db, struct mosquitto *context, const char *topic, int access)
{
	int rc;
	int i;
	struct mosquitto__security_options *opts;

	if(!context->id){
		return MOSQ_ERR_ACL_DENIED;
	}

	rc = mosquitto_acl_check_default(db, context, topic, access);
	if(rc != MOSQ_ERR_PLUGIN_DEFER){
		return rc;
	}
	/* Default check has accepted or deferred at this point.
	 * If no plugins exist we should accept at this point so set rc to success.
	 */
	rc = MOSQ_ERR_SUCCESS;

	if(db->config->per_listener_settings){
		opts = &context->listener->security_options;
	}else{
		opts = &db->config->security_options;
	}

	for(i=0; i<opts->auth_plugin_config_count; i++){
		rc = acl__check_single(&opts->auth_plugin_configs[i], context, topic, access);
		if(rc != MOSQ_ERR_PLUGIN_DEFER){
			return rc;
		}
	}

	/* If all plugins deferred, this is a denial. If rc == MOSQ_ERR_SUCCESS
	 * here, then no plugins were configured. */
	if(rc == MOSQ_ERR_PLUGIN_DEFER){
		rc = MOSQ_ERR_ACL_DENIED;
	}
	return rc;
}

int mosquitto_unpwd_check(struct mosquitto_db *db, struct mosquitto *context, const char *username, const char *password)
{
	int rc;
	int i;
	struct mosquitto__security_options *opts;

	rc = mosquitto_unpwd_check_default(db, context, username, password);
	if(rc != MOSQ_ERR_PLUGIN_DEFER){
		return rc;
	}
	/* Default check has accepted or deferred at this point.
	 * If no plugins exist we should accept at this point so set rc to success.
	 */
	if(db->config->per_listener_settings){
		opts = &context->listener->security_options;
	}else{
		opts = &db->config->security_options;
	}

	rc = MOSQ_ERR_SUCCESS;
	for(i=0; i<opts->auth_plugin_config_count; i++){
		if(opts->auth_plugin_configs[i].plugin.version == 3){
			rc = opts->auth_plugin_configs[i].plugin.unpwd_check_v3(
					opts->auth_plugin_configs[i].plugin.user_data,
					context,
					username,
					password);

		}else if(opts->auth_plugin_configs[i].plugin.version == 2){
			rc = opts->auth_plugin_configs[i].plugin.unpwd_check_v2(
					opts->auth_plugin_configs[i].plugin.user_data,
					username,
					password);
		}else{
			rc = MOSQ_ERR_INVAL;
		}
		if(rc != MOSQ_ERR_PLUGIN_DEFER){
			return rc;
		}
	}
	/* If all plugins deferred, this is a denial. If rc == MOSQ_ERR_SUCCESS
	 * here, then no plugins were configured. */
	if(rc == MOSQ_ERR_PLUGIN_DEFER){
		rc = MOSQ_ERR_AUTH;
	}
	return rc;
}

int mosquitto_psk_key_get(struct mosquitto_db *db, struct mosquitto *context, const char *hint, const char *identity, char *key, int max_key_len)
{
	int rc;
	int i;
	struct mosquitto__security_options *opts;

	rc = mosquitto_psk_key_get_default(db, context, hint, identity, key, max_key_len);
	if(rc != MOSQ_ERR_PLUGIN_DEFER){
		return rc;
	}

	/* Default check has accepted or deferred at this point.
	 * If no plugins exist we should accept at this point so set rc to success.
	 */

	if(db->config->per_listener_settings){
		opts = &context->listener->security_options;
	}else{
		opts = &db->config->security_options;
	}

	for(i=0; i<opts->auth_plugin_config_count; i++){
		if(opts->auth_plugin_configs[i].plugin.version == 3){
			rc = opts->auth_plugin_configs[i].plugin.psk_key_get_v3(
					opts->auth_plugin_configs[i].plugin.user_data,
					context,
					hint,
					identity,
					key,
					max_key_len);

		}else if(opts->auth_plugin_configs[i].plugin.version == 2){
			rc = opts->auth_plugin_configs[i].plugin.psk_key_get_v2(
					opts->auth_plugin_configs[i].plugin.user_data,
					hint,
					identity,
					key,
					max_key_len);
		}else{
			rc = MOSQ_ERR_INVAL;
		}
		if(rc != MOSQ_ERR_PLUGIN_DEFER){
			return rc;
		}
	}

	/* If all plugins deferred, this is a denial. If rc == MOSQ_ERR_SUCCESS
	 * here, then no plugins were configured. */
	if(rc == MOSQ_ERR_PLUGIN_DEFER){
		rc = MOSQ_ERR_AUTH;
	}
	return rc;
}

