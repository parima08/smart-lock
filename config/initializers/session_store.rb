# Be sure to restart your server when you modify this file.

GojiServer::Application.config.session_store :cookie_store, key: '_goji_server_session', secure: GojiServer.config.use_ssl_if_possible
