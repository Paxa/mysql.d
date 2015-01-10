module mysql.mysql_test;

import std.stdio;
import dunit.toolkit;

import mysql.mysql;
import mysql.test_helper;

// CHECK MYSQL CLIENT VERSION
unittest {
    if (Mysql.clientVersion < 50100) {
        writeln("Your mysqlclient version is ", Mysql.clientVersionString, ". Better use version >= 5.1");
    }
    assert(Mysql.clientVersion > 50100);
}

// Mysql.dbname
unittest {
    auto mysql = test_mysql_db_connection();
    assert(mysql.dbname == mysql.queryOneRow("SELECT DATABASE() as current_db;")["current_db"]);
}

// MYSQL PING
unittest {
    auto mysql = test_mysql_db_connection;
    assert(mysql.ping == 0);
}

// MAKE CONNECTION, CHANGE DB
unittest {
    auto mysql = test_mysql_db_connection();

    // drop database if exists
    mysql.query("DROP DATABASE IF EXISTS " ~ test_mysql_db);
    // create database
    mysql.query("CREATE DATABASE " ~ test_mysql_db);

    // check current database
    assertEqual(mysql.queryOneRow("SELECT DATABASE() as dbname;")["dbname"], "mysql");

    // change database
    mysql.selectDb(test_mysql_db);

    // check, it should be changed
    assertEqual(mysql.queryOneRow("SELECT DATABASE() as dbname;")["dbname"], test_mysql_db);
}

// ESCAPE STRING
unittest {
    auto mysql = new Mysql(test_mysql_host, test_mysql_user, test_mysql_password, test_mysql_db);
    assertEqual(mysql.escape("string \"with\" quotes"), "string \\\"with\\\" quotes");
}

// MYSQL STAT
unittest {
    auto mysql = new Mysql(test_mysql_host, test_mysql_user, test_mysql_password, test_mysql_db);
    mysql.stat.assertStartsWith("Uptime: ");
}

// MYSQL CLOSE
unittest {
    auto mysql = new Mysql(test_mysql_host, test_mysql_user, test_mysql_password, "mysql_d_testing");
    mysql.close();
}

// MYSQL OPTIONS
unittest {
    auto mysql = new Mysql();
    // if we comment this line then server will fall with errro
    // MySQL server has gone away :::: SHOW VARIABLES WHERE `variable_name` = 'pseudo_thread_id';
    mysql.setReconnect(true);
    mysql.connect(test_mysql_host, 0, test_mysql_user, test_mysql_password, test_mysql_db);

    auto res = mysql.query("SHOW VARIABLES WHERE `variable_name` = 'pseudo_thread_id';");

    auto mysq2 = new Mysql(test_mysql_host, test_mysql_user, test_mysql_password, test_mysql_db);
    mysq2.query("kill ?", res.front["Value"]);

    auto res2 = mysql.query("SHOW VARIABLES WHERE `variable_name` = 'pseudo_thread_id';");
    assertEqual(res.front["Value"], res.front["Value"]);
}