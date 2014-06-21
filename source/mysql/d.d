module mysql.d;

public import mysql.mysql;

// CHECK MYSQL CLIENT VERSION
unittest {
    import std.stdio;

    if (Mysql.clientVersion < 50100) {
        writeln("Your mysqlclient version is ", Mysql.clientVersionString, ". Better use version >= 5.1");
    }
    assert(Mysql.clientVersion > 50100);
}

// MAKE CONNECTION, CHANGE DB
unittest {
    import std.stdio;

    auto mysql = new Mysql("localhost", "root", "root", "mysql");

    // drop database if exists
    mysql.query("DROP DATABASE IF EXISTS mysql_d_testing");
    // create database
    mysql.query("CREATE DATABASE mysql_d_testing");

    // check current database
    assert(mysql.queryOneRow("SELECT DATABASE() as dbname;")["dbname"], "mysql");

    // change database
    mysql.selectDb("mysql_d_testing");

    // check, it should be changed
    assert(mysql.queryOneRow("SELECT DATABASE() as dbname;")["dbname"], "mysql_d_testing");
}

// ESCAPE STRING
unittest {
    import std.stdio;

    auto mysql = new Mysql("localhost", "root", "root", "mysql_d_testing");
    assert(mysql.escape("string \"with\" quotes"), "string \\\"with\\\" quotes");
}

// MAKE AN SQL QUERY
unittest {
    import std.stdio;

    auto mysql = new Mysql("localhost", "root", "root", "mysql_d_testing");

    // create table
    mysql.query("CREATE TABLE mysql_d_table (
        id INT NOT NULL AUTO_INCREMENT,
        name VARCHAR(100),
        date DATE,
        PRIMARY KEY (id)
    );");

    // list table
    auto q_res3 = mysql.query("show tables;");
    assert(q_res3.length() == 1);
    assert(q_res3.front()["Tables_in_mysql_d_testing"] == "mysql_d_table");

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

// MYSQL PING
unittest {
    import std.stdio;

    auto mysql = new Mysql("localhost", "root", "root", "mysql_d_testing");
    assert(mysql.ping == 0);
}