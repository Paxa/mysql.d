# Mysql.d

#### mysql library binding. Extraction from https://github.com/adamdruppe/arsd

Documentation is not ready yet

```D

inport mysql.d;

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

```