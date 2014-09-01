#!/usr/bin/env rdmd -I./source/
module example;

import std.string;
import std.stdio;
import mysql.d;

void main() {
    auto mysql = new Mysql("localhost", 3306, "root", "root", "mysql_d_testing");

    mysql.query("DROP TABLE IF EXISTS users");
    mysql.query("CREATE TABLE users (
        id INT NOT NULL AUTO_INCREMENT,
        name VARCHAR(100),
        sex tinyint(1) DEFAULT NULL,
        birthdate DATE,
        PRIMARY KEY (id)
    );");

    mysql.query("insert into users (name, sex, birthdate) values (?, ?, ?);", "Paul", 1, "1981-05-06");
    mysql.query("insert into users (name, sex, birthdate) values (?, ?, ?);", "Anna", 0, "1983-02-13");

    auto rows = mysql.query("select * from users");

    
    rows.length; // => 2
    //for (int i = 0; i < rows.length; i++) {
    //    rows.front
    //    auto user = rows.front;
    foreach (user; rows) {
        writefln("User %s, %s, born on %s", user["name"], user["sex"] == "1" ? "male" : "female", user["birthdate"]);
    }
    mysql.query("DROP TABLE `?`", "users");
}