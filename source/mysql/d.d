module mysql.d;

public import mysql.mysql;

unittest {
    import std.stdio;

    MySql connection1;
    connection1 = new MySql("localhost", "root", "root", "mysql");
    auto q_res1 = connection1.query("DROP DATABASE IF EXISTS mysql_d_testing");
    auto q_res2 = connection1.query("CREATE DATABASE mysql_d_testing");

    // TODO: fix connection.close()
    //connection1.close();

    MySql connection = new MySql("localhost", "root", "root", "mysql_d_testing");
    connection.query("CREATE TABLE mysql_d_table (
        id INT NOT NULL AUTO_INCREMENT,
        name VARCHAR(100),
        date DATE,
        PRIMARY KEY (id)
    );");

    auto q_res3 = connection.query("show tables;");
    assert(q_res3.length() == 1);
    assert(q_res3.front()["Tables_in_mysql_d_testing"] == "mysql_d_table");
}