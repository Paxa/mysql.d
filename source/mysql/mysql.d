module mysql.mysql;

import mysql.binding;

public import mysql.mysql_result;
public import mysql.mysql_row;
import mysql.query_interface;

import std.stdio;
import std.exception;
import std.typecons;

class MysqlDatabaseException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

alias Connection = Mysql;

class Mysql {
    private string _dbname;
    private MYSQL* mysql;
    private string lastErrorMsg;

    this(string host, string user, string pass, string db) {
        initMysql();
        connect(host, 0, user, pass, db, null);
    }

    this(string host, uint port, string user, string pass, string db, string charset = null) {
        initMysql();
        connect(host, port, user, pass, db, null, charset);
    }

    this(string host, string user, string pass) {
        initMysql();
        connect(host, user, pass);
    }

    this() {
        initMysql();
    }

    private void initMysql () {
        mysql = enforce!(MysqlDatabaseException)(mysql_init(null), "Couldn't init mysql");
        setReconnect(true);
    }

    void connect(string host, uint port, string user, string pass, string db, string unixSocket, string charset = null) {
        enforce!(MysqlDatabaseException)(
            mysql_real_connect(mysql,
                toCstring(host),
                toCstring(user),
                toCstring(pass),
                toCstring(db),
                port,
                unixSocket ? toCstring(unixSocket) : null,
                0),
            error()
        );

        _dbname = db;

        if (charset != null) setCharset(charset);
    }

    void connect(string host, uint port, string user, string pass, string db, string charset="utf8") {
        connect(host, port, user, pass, db, null, charset);
    }

    void connect(string host, string user, string pass, string db) {
        connect(host, 0, user, pass, db, null);
    }

    void connect(string host, string user, string pass) {
        connect(host, 0, user, pass, null, null);
    }

    int selectDb(string newDbName) {
        auto res = mysql_select_db(mysql, toCstring(newDbName));
        _dbname = newDbName;
        return res;
    }

    string dbname() {
        return _dbname;
    }

    int setOption(mysql_option option, const void* value) {
        return mysql_options(mysql, option, &value);
    }

    int setReconnect(bool value) {
        return setOption(mysql_option.MYSQL_OPT_RECONNECT, &value);
    }

    int setConnectTimeout(int value) {
        return setOption(mysql_option.MYSQL_OPT_CONNECT_TIMEOUT, cast(const(char*))value);
    }

    int setCharset(string charset) {
        return mysql_set_character_set(mysql, toCstring(charset));
    }

    string charset() {
        return fromCstring(mysql_character_set_name(mysql));
    }

    static ulong clientVersion() {
        return mysql_get_client_version();
    }

    static string clientVersionString() {
        return fromCstring(mysql_get_client_info());
    }

    void startTransaction() {
        query("START TRANSACTION");
    }

    void commit() {
        query("COMMIT");
    }

    void rollback() {
        query("ROLLBACK");
    }

    string error() {
        return fromCstring(mysql_error(mysql));
    }

    void close() {
        if (mysql) {
            mysql_close(mysql);
            mysql = null;
        }
    }

    ~this() {
        close();
    }

    // MYSQL API call
    int lastInsertId() {
        return cast(int) mysql_insert_id(mysql);
    }

    // MYSQL API call
    int affectedRows() {
        return cast(int) mysql_affected_rows(mysql);
    }

    // MYSQL API call
    string escape(string str) {
        ubyte[] buffer = new ubyte[str.length * 2 + 1];
        buffer.length = mysql_real_escape_string(mysql, buffer.ptr, cast(cstring) str.ptr, cast(uint) str.length);

        return cast(string) buffer;
    }

    // MYSQL API call
    MysqlResult queryImpl(string sql) {
        enforce!(MysqlDatabaseException)(
            !mysql_query(mysql, toCstring(sql)),
        error() ~ " :::: " ~ sql);

        return new MysqlResult(mysql_store_result(mysql), sql);
    }

    // To be used with commands that do not return a result (INSERT, UPDATE, etc...)
    bool execImpl(string sql) {
        bool success = false;

        if (mysql_query(mysql, toCstring(sql)) == 0) {
            success = true;
            this.lastErrorMsg = "";
        } else {
            this.lastErrorMsg = error() ~ " :::: " ~ sql;
        }

        return success;
    }

    // MYSQL API call
    int ping() {
        return mysql_ping(mysql);
    }

    // MYSQL API call
    string stat() {
        return fromCstring(mysql_stat(mysql));
    }

    // ====== helpers ======

    // Smart interface thing.
    // accept multiple attributes and make replacement of '?' in sql
    // like this:
    // auto row = mysql.query("select * from table where id = ?", 10);
    MysqlResult query(T...)(string sql, T t) {
        return queryImpl(QueryInterface.makeQuery(this, sql, t));
    }

    bool exec(T...)(string sql, T t) {
        return execImpl(QueryInterface.makeQuery(this, sql, t));
    }

    string dbErrorMsg() {
        return this.lastErrorMsg;
    }

    // simply make mysq.query().front
    // and if no rows then raise an exception
    Nullable!MysqlRow queryOneRow(string file = __FILE__, size_t line = __LINE__, T...)(string sql, T t) {
        auto res = query(sql, t);
        if (res.empty) {
            return Nullable!MysqlRow.init;
        }
        auto row = res.front;

        return Nullable!MysqlRow(row);
    }

/*
    ResultByDataObject!R queryDataObject(R = DataObject, T...)(string sql, T t) {
        // modify sql for the best data object grabbing
        sql = fixupSqlForDataObjectUse(sql);

        auto magic = query(sql, t);
        return ResultByDataObject!R(cast(MysqlResult) magic, this);
    }


    ResultByDataObject!R queryDataObjectWithCustomKeys(R = DataObject, T...)(string[string] keyMapping, string sql, T t) {
        sql = fixupSqlForDataObjectUse(sql, keyMapping);

        auto magic = query(sql, t);
        return ResultByDataObject!R(cast(MysqlResult) magic, this);
    }
*/
package:

    bool busy = false;
}

/*
struct ResultByDataObject(ObjType) if (is(ObjType : DataObject)) {
    MysqlResult result;
    Mysql mysql;

    this(MysqlResult r, Mysql mysql) {
        result = r;
        auto fields = r.fields();
        this.mysql = mysql;

        foreach(i, f; fields) {
            string tbl = fromCstring(f.org_table is null ? f.table : f.org_table, f.org_table is null ? f.table_length : f.org_table_length);
            mappings[fromCstring(f.name)] = tuple(
                    tbl,
                    fromCstring(f.org_name is null ? f.name : f.org_name, f.org_name is null ? f.name_length : f.org_name_length));
        }


    }

    Tuple!(string, string)[string] mappings;

    ulong length() { return result.length; }
    bool empty() { return result.empty; }
    void popFront() { result.popFront(); }
    ObjType front() {
        return new ObjType(mysql, result.front.toAA, mappings);
    }
    // would it be good to add a new() method? would be valid even if empty
    // it'd just fill in the ID's at random and allow you to do the rest

    @disable this(this) { }
}
*/


class EmptyResultException : Exception {
    this(string message, string file = __FILE__, size_t line = __LINE__) {
        super(message, file, line);
    }
}


/*
void main() {
    auto mysql = new Mysql("localhost", "uname", "password", "test");
    scope(exit) delete mysql;

    mysql.query("INSERT INTO users (id, password) VALUES (?, ?)", 10, "lol");

    foreach(row; mysql.query("SELECT * FROM users")) {
        writefln("%s %s %s %s", row["id"], row[0], row[1], row["username"]);
    }
}
*/

/+
    mysql.linq.tablename.field[key] // select field from tablename where id = key

    mysql.link["name"].table.field[key] // select field from table where name = key


    auto q = mysql.prepQuery("select id from table where something");
    q.sort("name");
    q.limit(start, count);
    q.page(3, pagelength = ?);

    q.execute(params here); // returns the same Result range as query
+/

/*
void main() {
    auto db = new Mysql("localhost", "uname", "password", "test");
    foreach(item; db.queryDataObject("SELECT users.*, username
        FROM users, password_manager_accounts
        WHERE password_manager_accounts.user_id =  users.id LIMIT 5")) {
        writefln("item: %s, %s", item.id, item.username);
        item.first = "new";
        item.last = "new2";
        item.username = "kill";
        //item.commitChanges();
    }
}
*/


/*
Copyright: Adam D. Ruppe, 2009 - 2011
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors: Adam D. Ruppe, with contributions from Nick Sabalausky

        Copyright Adam D. Ruppe 2009 - 2011.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
        http://www.boost.org/LICENSE_1_0.txt)
*/

