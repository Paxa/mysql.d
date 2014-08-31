module mysql.test_helper;

import mysql.test_config;
import mysql.mysql;

Mysql testing_db_init() {
    //auto mysql = new Mysql();
    //mysql.connect(null, 0, test_mysql_user, test_mysql_password, "mysql", "/tmp/custom_mysql.sock");
    auto mysql = new Mysql(test_mysql_host, test_mysql_user, test_mysql_password, "mysql");
    mysql.query("DROP DATABASE IF EXISTS " ~ test_mysql_db);
    mysql.query("CREATE DATABASE " ~ test_mysql_db);
    mysql.selectDb(test_mysql_db);
    return mysql;
}