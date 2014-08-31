# Mysql.d

### mysql library binding. Extraction from https://github.com/adamdruppe/arsd

[![Build Status](https://drone.io/github.com/Paxa/mysql.d/status.png)](https://drone.io/github.com/Paxa/mysql.d/latest)

Documentation is not ready yet

```D
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
    foreach (user; rows) {
        writefln("User %s, %s, born on %s", user["name"], user["sex"] == "1" ? "male" : "female", user["birthdate"]);
    }
}
```

Output is:
```
User Paul, male, born on 1981-05-06
User Anna, female, born on 1983-02-13
```

#### Compiling

* Install dub with `brew install dub` or from here http://code.dlang.org/download
* Run `dub`

#### Testing

* run `dub test`

#### Example application

[http://mysql-d.mooo.com/](http://mysql-d.mooo.com/)