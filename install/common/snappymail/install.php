<?php

$_ENV["SNAPPYMAIL_INCLUDE_AS_API"] = true;
require_once "/var/lib/snappymail/index.php";

$oConfig = \RainLoop\Api::Config();

// Change default login data / key
$oConfig->Set("security", "admin_login", $argv[1]);
$oConfig->Set("security", "admin_panel_key", $argv[1]);
$oConfig->SetPassword($argv[2]);

// Allow Contacts to be saved in database
$oConfig->Set("contacts", "enable", "On");
$oConfig->Set("contacts", "allow_sync", "On");
$oConfig->Set("contacts", "type", "mysql");
$oConfig->Set("contacts", "pdo_dsn", "mysql:host=127.0.0.1;port=3306;dbname=snappymail");
$oConfig->Set("contacts", "pdo_user", "snappymail");
$oConfig->Set("contacts", "pdo_password", $argv[3]);

// Plugins
$oConfig->Set("plugins", "enable", "On");

\SnappyMail\Repository::installPackage("plugin", "change-password");
\SnappyMail\Repository::installPackage("plugin", "change-password-lokahost");

$sFile = APP_PRIVATE_DATA . "configs/plugin-change-password.json";
if (!file_exists($sFile)) {
	file_put_contents(
		"$sFile",
		json_encode(
			[
				"plugin" => [
					"pass_min_length" => 8,
					"pass_min_strength" => 60,
					"driver_lokahost_enabled" => true,
					"driver_lokahost_allowed_emails" => "*",
					"lokahost_host" => gethostname(),
					"lokahost_port" => $argv[4], // $BACKEND_PORT
				],
			],
			JSON_PRETTY_PRINT,
		),
	);
}
\SnappyMail\Repository::enablePackage("change-password");

\SnappyMail\Repository::installPackage("plugin", "add-x-originating-ip-header");
\SnappyMail\Repository::enablePackage("add-x-originating-ip-header");
$sFile = APP_PRIVATE_DATA . "configs/plugin-add-x-originating-ip-header.json";
if (!file_exists($sFile)) {
	file_put_contents(
		"$sFile",
		json_encode(
			[
				"plugin" => [
					"check_proxy" => true,
				],
			],
			JSON_PRETTY_PRINT,
		),
	);
}

$oConfig->Save();

$sFile = APP_PRIVATE_DATA . "domains/lokahost.json";
if (!file_exists($sFile)) {
	$config = json_decode(APP_PRIVATE_DATA . "domains/default.json", true);
	$config["IMAP"]["shortLogin"] = true;
	$config["SMTP"]["shortLogin"] = true;
	file_put_contents($sFile, json_encode($config, JSON_PRETTY_PRINT));
}
