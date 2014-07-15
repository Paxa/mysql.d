module mysql.test_helper;

import mysql.mysql;

string test_mysql_host = "localhost";
string test_mysql_user = "root";
string test_mysql_password = "root";
string test_mysql_db = "mysql_d_testing";

Mysql testing_db_init() {
    auto mysql = new Mysql(test_mysql_host, test_mysql_user, test_mysql_password, "mysql");
    mysql.query("DROP DATABASE IF EXISTS " ~ test_mysql_db);
    mysql.query("CREATE DATABASE " ~ test_mysql_db);
    mysql.selectDb(test_mysql_db);
    return mysql;
}