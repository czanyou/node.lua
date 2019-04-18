#include <stdio.h>
#include <string.h>
#include <mosquitto.h>
#include <mosquitto_broker.h>
#include <mosquitto_plugin.h>

int mosquitto_auth_plugin_version(void)
{
	return MOSQ_AUTH_PLUGIN_VERSION;
}

int mosquitto_auth_plugin_init(void **user_data, struct mosquitto_opt *auth_opts, int auth_opt_count)
{
	return MOSQ_ERR_SUCCESS;
}

int mosquitto_auth_plugin_cleanup(void *user_data, struct mosquitto_opt *auth_opts, int auth_opt_count)
{
	return MOSQ_ERR_SUCCESS;
}

int mosquitto_auth_security_init(void *user_data, struct mosquitto_opt *auth_opts, int auth_opt_count, bool reload)
{
	return MOSQ_ERR_SUCCESS;
}

int mosquitto_auth_security_cleanup(void *user_data, struct mosquitto_opt *auth_opts, int auth_opt_count, bool reload)
{
	return MOSQ_ERR_SUCCESS;
}

int mosquitto_auth_acl_check(void *user_data, int access, const struct mosquitto *client, const struct mosquitto_acl_msg *msg)
{
	return MOSQ_ERR_PLUGIN_DEFER;
}

int mosquitto_auth_unpwd_check(void *user_data, const struct mosquitto *client, const char *username, const char *password)
{
	if(!strcmp(username, "test-username") && password && !strcmp(password, "cnwTICONIURW")){
		return MOSQ_ERR_SUCCESS;
	}else if(!strcmp(username, "readonly")){
		return MOSQ_ERR_SUCCESS;
	}else if(!strcmp(username, "test-username@v2")){
		return MOSQ_ERR_PLUGIN_DEFER;
	}else{
		return MOSQ_ERR_AUTH;
	}
}

int mosquitto_auth_psk_key_get(void *user_data, const struct mosquitto *client, const char *hint, const char *identity, char *key, int max_key_len)
{
	return MOSQ_ERR_AUTH;
}

