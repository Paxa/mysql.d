module mysql.mysql_result_test;

import std.stdio;
import mysql.mysql;

import mysql.test_helper;
import dunit.toolkit;

// MAKE AN SQL QUERY
unittest {
    auto mysql = testing_db_init();

    // create table
    mysql.query("CREATE TABLE mysql_d_table (
        id INT NOT NULL AUTO_INCREMENT,
        name VARCHAR(100),
        date DATE,
        PRIMARY KEY (id)
    );");
    
    // list table
    auto q_res3 = mysql.query("show tables;");
    assertEqual(q_res3.length, 1);
    assertEqual(q_res3.front()["Tables_in_mysql_d_testing"], "mysql_d_table");

    // insert some
    mysql.query("INSERT INTO mysql_d_table (name, date) values (?, ?);", "Paul", "1989-05-06");
    assert(mysql.lastInsertId == 1);

    // select it
    auto res = mysql.query("select * from mysql_d_table;");
    assert(res.length == 1);
    assert(res.empty == false);

    assert(res.getFieldIndex("date") == 2);

    assert(res.fieldNames() == ["id", "name", "date"]);

    assert(res.front["id"] == "1");
    assert(res.front["name"] == "Paul");
    assert(res.front["date"] == "1989-05-06");

    // this should raise an error
    bool catched = false;
    try {
        res.getFieldIndex("column_which_not_exists");
    } catch (Exception e) {
        assert(e.msg == "column_which_not_exists not in result");
        catched = true;
    }
    assert(catched == true);

    writeln(mysql.stat);
    // TODO: fix mysql.close()
    // mysql.close();
}
