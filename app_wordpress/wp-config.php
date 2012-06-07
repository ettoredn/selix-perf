<?php
/**
 * The base configurations of the WordPress.
 *
 * This file has the following configurations: MySQL settings, Table Prefix,
 * Secret Keys, WordPress Language, and ABSPATH. You can find more information
 * by visiting {@link http://codex.wordpress.org/Editing_wp-config.php Editing
 * wp-config.php} Codex page. You can get the MySQL settings from your web host.
 *
 * This file is used by the wp-config.php creation script during the
 * installation. You don't have to use the web site, you can just copy this file
 * to "wp-config.php" and fill in the values.
 *
 * @package WordPress
 */

// ** MySQL settings - You can get this info from your web host ** //
/** The name of the database for WordPress */
define('DB_NAME', 'wordpress');

/** MySQL database username */
define('DB_USER', 'root');

/** MySQL database password */
define('DB_PASSWORD', 'ettore');

/** MySQL hostname */
define('DB_HOST', 'localhost');

/** Database Charset to use in creating database tables. */
define('DB_CHARSET', 'utf8');

/** The Database Collate type. Don't change this if in doubt. */
define('DB_COLLATE', '');

/**#@+
 * Authentication Unique Keys and Salts.
 *
 * Change these to different unique phrases!
 * You can generate these using the {@link https://api.wordpress.org/secret-key/1.1/salt/ WordPress.org secret-key service}
 * You can change these at any point in time to invalidate all existing cookies. This will force all users to have to log in again.
 *
 * @since 2.6.0
 */
define('AUTH_KEY',         '7%;?2n& 1Ye[$G_8z5OI@bB1-8;MDfd 58xLx+Kx+lE>k@1(Q=[5iL/n?{yJ!_(-');
define('SECURE_AUTH_KEY',  '|4`-lXCo(dnZaM(!o(w+*sb6^;|m.ByHKp(J//)(#> +XD{te]P|cm`#Rcpe(/$~');
define('LOGGED_IN_KEY',    'qbH:x9RGD?sfL{60e=0t.1@Eok7Zc:|letFqkB1V=-{F9c>gznEbD^GB-``1%Ocp');
define('NONCE_KEY',        '`=8c?|p_E)]<Ew3zV>lXkde|C9GT)-Nt0&q-5AfHB7 N?-7_-u.yeB r<n>TSUDv');
define('AUTH_SALT',        '5_?;]5qg_PM):-?bbNq}A-lMd*rs|4pEW$T[ujn_#NbI#g[tjAoB_#Ny|5^S&m+B');
define('SECURE_AUTH_SALT', '6*n1$`=>KFaIV#|LiJ(X]00rH#oqU%~`{|I<F[EYRg# %< CX!|x%+`uIr0r;*t?');
define('LOGGED_IN_SALT',   'Yz9cF@d|^+Y7,z_@o5,s*gA4<$g]7S~YV@DA?Q,2u%#eGRs- l&k/H8QIa=vs/2M');
define('NONCE_SALT',       'wy$=2z[qUf)_uSSs0 R6ZddW1$i{) jf*o+HgcDEg%jzAt?kaqAI5|p:XO4>mS&|');

/**#@-*/

/**
 * WordPress Database Table prefix.
 *
 * You can have multiple installations in one database if you give each a unique
 * prefix. Only numbers, letters, and underscores please!
 */
$table_prefix  = 'wp_';

/**
 * WordPress Localized Language, defaults to English.
 *
 * Change this to localize WordPress. A corresponding MO file for the chosen
 * language must be installed to wp-content/languages. For example, install
 * de_DE.mo to wp-content/languages and set WPLANG to 'de_DE' to enable German
 * language support.
 */
define('WPLANG', '');

/**
 * For developers: WordPress debugging mode.
 *
 * Change this to true to enable the display of notices during development.
 * It is strongly recommended that plugin and theme developers use WP_DEBUG
 * in their development environments.
 */
define('WP_DEBUG', false);

/* That's all, stop editing! Happy blogging. */

/** Absolute path to the WordPress directory. */
if ( !defined('ABSPATH') )
	define('ABSPATH', dirname(__FILE__) . '/');

/** Sets up WordPress vars and included files. */
require_once(ABSPATH . 'wp-settings.php');
