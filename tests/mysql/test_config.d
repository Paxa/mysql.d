module mysql.test_config;

import std.process;
import std.stdio;

string test_mysql_host = "localhost";
string test_mysql_user = "root";
string test_mysql_password = "root";
string test_mysql_db = "mysql_d_testing";

void test_mysql_config_env () {
    if (environment.get("MYSQL_HOST")) {
        test_mysql_host = environment["MYSQL_HOST"];
    }

    if (environment.get("MYSQL_USER")) {
        test_mysql_user = environment["MYSQL_USER"];
    }

    if (environment.get("MYSQL_PASSWORD", "^^^") != "^^^") {
        test_mysql_password = environment["MYSQL_PASSWORD"];
    }

    if (environment.get("MYSQL_DB")) {
        test_mysql_db = environment["MYSQL_DB"];
    }

    writefln("Connecting to: %s:%s@%s/%s", test_mysql_user, test_mysql_password, test_mysql_host, test_mysql_db);
}