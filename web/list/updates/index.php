<?php
$TAB = "UPDATES";

// Main include
include $_SERVER["DOCUMENT_ROOT"] . "/inc/main.php";

// Check user
if ($_SESSION["userContext"] != "admin") {
	header("Location: /list/user");
	exit();
}

// Data
exec(LOKAHOST_CMD . "v-list-sys-lokahost-updates json", $output, $return_var);
$data = json_decode(implode("", $output), true);
unset($output);
exec(LOKAHOST_CMD . "v-list-sys-lokahost-autoupdate plain", $output, $return_var);
$autoupdate = $output["0"];
unset($output);

// Render page
render_page($user, $TAB, "list_updates");

// Back uri
$_SESSION["back"] = $_SERVER["REQUEST_URI"];
