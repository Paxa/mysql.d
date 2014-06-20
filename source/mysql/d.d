module mysql.d;

public import mysql.mysql;

unittest {
    import std.stdio;

    // Connect to database
    Mysql connection1;
    connection1 = new Mysql("localhost", "root", "root", "mysql");

    // drop database if exists
    connection1.query("DROP DATABASE IF EXISTS mysql_d_testing");
    // create database
    connection1.query("CREATE DATABASE mysql_d_testing");

    // TODO: fix connection.close()
    //connection1.close();

    // connect to new created database
    Mysql connection = new Mysql("localhost", "root", "root", "mysql_d_testing");

    // create table
    connection.query("CREATE TABLE mysql_d_table (
        id INT NOT NULL AUTO_INCREMENT,
        name VARCHAR(100),
        date DATE,
        PRIMARY KEY (id)
    );");

    // list table
    auto q_res3 = connection.query("show tables;");
    assert(q_res3.length() == 1);
    assert(q_res3.front()["Tables_in_mysql_d_testing"] == "mysql_d_table");

    // escape strings
    assert(connection.escape("string \"with\" quotes"), "string \\\"with\\\" quotes");

    // insert some
    connection.query("INSERT INTO mysql_d_table (name, date) values (?, ?);", "Paul", "1989-05-06");
    assert(connection.lastInsertId == 1);

    // select it
    auto res = connection.query("select * from mysql_d_table;");
    assert(res.length == 1);
    assert(res.empty == false);

    assert(res.getFieldIndex("date") == 2);

    assert(res.fieldNames() == ["id", "name", "date"]);

    assert(res.front["id"] == "1");
    assert(res.front["name"] == "Paul");
    assert(res.front["date"] == "1989-05-06");

    try {
        res.getFieldIndex("column_which_not_exists");
    } catch (Exception e) {
        assert(e.msg == "column_which_not_exists not in result");
    }
}