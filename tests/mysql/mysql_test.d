module mysql.mysql_test;

import std.stdio;
import dunit.toolkit;
import mysql.mysql;

// CHECK MYSQL CLIENT VERSION
unittest {
    if (Mysql.clientVersion < 50100) {
        writeln("Your mysqlclient version is ", Mysql.clientVersionString, ". Better use version >= 5.1");
    }
    assert(Mysql.clientVersion > 50100);
}

// MYSQL PING
unittest {
    auto mysql = new Mysql("localhost", "root", "root", "mysql");
    assert(mysql.ping == 0);
}

// MAKE CONNECTION, CHANGE DB
unittest {
    auto mysql = new Mysql("localhost", "root", "root", "mysql");

    // drop database if exists
    mysql.query("DROP DATABASE IF EXISTS mysql_d_testing");
    // create database
    mysql.query("CREATE DATABASE mysql_d_testing");

    // check current database
    assertEqual(mysql.queryOneRow("SELECT DATABASE() as dbname;")["dbname"], "mysql");

    // change database
    mysql.selectDb("mysql_d_testing");

    // check, it should be changed
    assertEqual(mysql.queryOneRow("SELECT DATABASE() as dbname;")["dbname"], "mysql_d_testing");
}

// ESCAPE STRING
unittest {
    auto mysql = new Mysql("localhost", "root", "root", "mysql_d_testing");
    assertEqual(mysql.escape("string \"with\" quotes"), "string \\\"with\\\" quotes");
}

// MYSQL STAT
unittest {
    auto mysql = new Mysql("localhost", "root", "root", "mysql_d_testing");
    mysql.stat.assertStartsWith("Uptime: ");
}

/*
TODO: Fix it
// MYSQL CLOSE
unittest {
    auto mysql = new Mysql("localhost", "root", "root", "mysql_d_testing");
    mysql.close();
}
*/

// MYSQL OPTIONS
unittest {
    auto mysql = new Mysql();
    // if we comment this line then server will fall with errro
    // MySQL server has gone away :::: SHOW VARIABLES WHERE `variable_name` = 'pseudo_thread_id';
    mysql.setReconnect(true);
    mysql.connect("localhost", "root", "root", "mysql_d_testing");

    auto res = mysql.query("SHOW VARIABLES WHERE `variable_name` = 'pseudo_thread_id';");

    auto mysq2 = new Mysql("localhost", "root", "root", "mysql_d_testing");
    mysq2.query("kill ?", res.front["Value"]);

    auto res2 = mysql.query("SHOW VARIABLES WHERE `variable_name` = 'pseudo_thread_id';");
    assertEqual(res.front["Value"], res.front["Value"]);
}