module mysql.test_helper;

import std.stdio;
import std.process;
import mysql.mysql;

string test_mysql_host = "localhost";
string test_mysql_user = "root";
string test_mysql_password = "";
string test_mysql_db = "mysql_d_testing";

bool test_mysql_info_printed = false;

Mysql test_mysql_db_connection () {

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

    if (!test_mysql_info_printed) {
        writefln("Connecting to: %s:%s@%s/%s", test_mysql_user, test_mysql_password, test_mysql_host, test_mysql_db);
        test_mysql_info_printed = true;
    }

    return new Mysql(test_mysql_host, test_mysql_user, test_mysql_password, "mysql");
}

Mysql testing_db_init() {
    auto mysql = test_mysql_db_connection();

    mysql.query("DROP DATABASE IF EXISTS " ~ test_mysql_db);
    mysql.query("CREATE DATABASE " ~ test_mysql_db);
    mysql.selectDb(test_mysql_db);
    return mysql;
}


string[] listTables(Mysql mysql) {
    auto q_res = mysql.query("show tables;");

    string[] tables;
    string col = q_res.fieldNames[0];

    foreach (table; q_res) {
        tables ~= table[q_res.fieldNames[0]];
    }
    return tables;
}
