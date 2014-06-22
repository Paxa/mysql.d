module mysql.mysql_row_test;

import std.stdio;
import dunit.toolkit;

import mysql.mysql;
import mysql.test_helper;

unittest {
    auto mysql = testing_db_init();

    // create table
    mysql.query("CREATE TABLE mysql_d_table (
        id INT NOT NULL AUTO_INCREMENT,
        name VARCHAR(100),
        date DATE,
        PRIMARY KEY (id)
    );");

    mysql.query("INSERT INTO mysql_d_table (name, date) values (?, ?);", "Paul", "1989-05-06");

    auto row = mysql.queryOneRow("select * from mysql_d_table;");

    assert(row["id"] == "1");
    assert(row["name"] == "Paul");
    assert(row["date"] == "1989-05-06");
}