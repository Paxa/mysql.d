module mysql.mysql_query_interface_test;

import std.stdio;
import dunit.toolkit;

import mysql.mysql;
import mysql.query_interface;
import mysql.test_helper;


// case with `?`
unittest {
    auto mysql = testing_db_init();
    string table_name = "windows";
    mysql.query("CREATE TABLE `?` (id INT);", table_name);
    mysql.query("DROP TABLE `?`", table_name);

    assertEqual(mysql.listTables, []);
}

// case with long
unittest {
    long num = 5;
    auto query = QueryInterface.makeQuery(new Mysql, "select 1 + ? as ss", num);
    assertEqual(query, "select 1 + '5' as ss");
}


// case with int
unittest {
    int num = 5;
    auto query = QueryInterface.makeQuery(new Mysql, "select 1 + ? as ss", num);
    assertEqual(query, "select 1 + '5' as ss");
}


// case with ubyte
unittest {
    ubyte num = 0x05;
    auto query = QueryInterface.makeQuery(new Mysql, "select 1 + ? as ss", num);
    assertEqual(query, "select 1 + '5' as ss");
}


// case with byte
unittest {
    byte num = 0x05;
    auto query = QueryInterface.makeQuery(new Mysql, "select 1 + ? as ss", num);
    assertEqual(query, "select 1 + '5' as ss");
}


// case with short
unittest {
    short num = 5;
    auto query = QueryInterface.makeQuery(new Mysql, "select 1 + ? as ss", num);
    assertEqual(query, "select 1 + '5' as ss");
}

// case with ushort
unittest {
    ushort num = 5;
    auto query = QueryInterface.makeQuery(new Mysql, "select 1 + ? as ss", num);
    assertEqual(query, "select 1 + '5' as ss");
}

// case with float
unittest {
    float num = 5.5;
    auto query = QueryInterface.makeQuery(new Mysql, "select 1 + ? as ss", num);
    assertEqual(query, "select 1 + '5.5' as ss");
}

// case with double
unittest {
    double num = 5.5;
    auto query = QueryInterface.makeQuery(new Mysql, "select 1 + ? as ss", num);
    assertEqual(query, "select 1 + '5.5' as ss");
}

// case with real
unittest {
    real num = 5.5;
    auto query = QueryInterface.makeQuery(new Mysql, "select 1 + ? as ss", num);
    assertEqual(query, "select 1 + '5.5' as ss");
}

// case with array
unittest {
    int[4] values = [0, 1, 2, 3];
    auto query = QueryInterface.makeQuery(new Mysql, "select 1 in (?) as ss", values);
    assertEqual(query, "select 1 in (0, 1, 2, 3) as ss");
}

// case with array int[]
unittest {
    int[4] values = [0, 1, 2, 3];
    auto query = QueryInterface.makeQuery(new Mysql, "select 1 in (?) as ss", values);
    assertEqual(query, "select 1 in (0, 1, 2, 3) as ss");
}

// case with array float[]
unittest {
    float[4] values = [0, 1.5, 2, 3];
    auto query = QueryInterface.makeQuery(new Mysql, "select 1 in (?) as ss", values);
    assertEqual(query, "select 1 in (0, 1.5, 2, 3) as ss");
}

// case with array string[]
unittest {
    string[3] values = ["apple", "banana", "mangoostene"];
    auto query = QueryInterface.makeQuery(new Mysql, "select 1 in (?) as ss", values);
    assertEqual(query, "select 1 in ('apple', 'banana', 'mangoostene') as ss");
}