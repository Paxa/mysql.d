module mysql.test_helper;

import mysql.mysql;

Mysql testing_db_init() {
    auto mysql = new Mysql("localhost", "root", "root", "mysql");
    mysql.query("DROP DATABASE IF EXISTS mysql_d_testing");
    mysql.query("CREATE DATABASE mysql_d_testing");
    mysql.selectDb("mysql_d_testing");
    return mysql;
}