module mysql.mysql_exec_test;

import std.stdio;
import dunit.toolkit;

import mysql.mysql;
import mysql.test_helper;

unittest {
    auto mysql = testing_db_init();

    bool result = mysql.exec("select a + 1");

    assertEqual(result, false);
    assertEqual(mysql.dbErrorMsg, "Unknown column 'a' in 'field list' :::: select a + 1");
}