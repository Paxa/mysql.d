module mysql.mysql;

import mysql.binding;
public import mysql.database;
public import mysql.mysql_result;

import std.stdio;
import std.exception;
import core.stdc.config;

class Mysql : Database {
    this(string host, string user, string pass, string db) {
        mysql = enforceEx!(DatabaseException)(
            mysql_init(null),
            "Couldn't init mysql");
        enforceEx!(DatabaseException)(
            mysql_real_connect(mysql, toCstring(host), toCstring(user), toCstring(pass), toCstring(db), 0, null, 0),
            error());

        dbname = db;

        // we want UTF8 for everything
        query("SET NAMES 'utf8'");
    }

    string dbname;

    int selectDb(string newDbName) {
      auto res = mysql_select_db(mysql, toCstring(newDbName));
      dbname = newDbName;
      return res;
    }

    static ulong clientVersion() {
      return mysql_get_client_version();
    }

    static string clientVersionString() {
      return fromCstring(mysql_get_client_info());
    }

    override void startTransaction() {
        query("START TRANSACTION");
    }

    string error() {
        return fromCstring(mysql_error(mysql));
    }

    void close() {
        mysql_close(mysql);
    }

    ~this() {
        close();
    }

    // MYSQL API call
    int lastInsertId() {
        return cast(int) mysql_insert_id(mysql);
    }

    int insert(string table, MysqlResult result, string[string] columnsToModify, string[] columnsToSkip) {
        assert(!result.empty);
        string sql = "INSERT INTO `" ~ table ~ "` ";

        string cols = "(";
        string vals = "(";
        bool outputted = false;

        string[string] columns;
        auto cnames = result.fieldNames;
        foreach(i, col; result.front.toStringArray) {
            bool skipMe = false;
            foreach(skip; columnsToSkip) {
                if(cnames[i] == skip) {
                    skipMe = true;
                    break;
                }
            }
            if(skipMe)
                continue;

            if(outputted) {
                cols ~= ",";
                vals ~= ",";
            } else
                outputted = true;

            cols ~= cnames[i];

            if(result.columnIsNull[i] && cnames[i] !in columnsToModify)
                vals ~= "NULL";
            else {
                string v = col;
                if(cnames[i] in columnsToModify)
                    v = columnsToModify[cnames[i]];

                vals ~= "'" ~ escape(v) ~ "'";

            }
        }

        cols ~= ")";
        vals ~= ")";

        sql ~= cols ~ " VALUES " ~ vals;

        query(sql);

        result.popFront;

        return lastInsertId;
    }

    // MYSQL API call
    string escape(string str) {
        ubyte[] buffer = new ubyte[str.length * 2 + 1];
        buffer.length = mysql_real_escape_string(mysql, buffer.ptr, cast(cstring) str.ptr, cast(uint) str.length);

        return cast(string) buffer;
    }

    string escaped(T...)(string sql, T t) {
        static if(t.length > 0) {
            string fixedup;
            int pos = 0;


            void escAndAdd(string str, int q) {
                ubyte[] buffer = new ubyte[str.length * 2 + 1];
                buffer.length = mysql_real_escape_string(mysql, buffer.ptr, cast(cstring) str.ptr, str.length);

                fixedup ~= sql[pos..q] ~ '\'' ~ cast(string) buffer ~ '\'';

            }

            foreach(a; t) {
                int q = sql[pos..$].indexOf("?");
                if(q == -1)
                    break;
                q += pos;

                static if(__traits(compiles, t is null)) {
                    if(t is null)
                        fixedup  ~= sql[pos..q] ~ "NULL";
                    else
                        escAndAdd(to!string(*a), q);
                } else {
                    string str = to!string(a);
                    escAndAdd(str, q);
                }

                pos = q+1;
            }

            fixedup ~= sql[pos..$];

            sql = fixedup;

            //writefln("\n\nExecuting sql: %s", sql);
        }

        return sql;
    }


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


    // MYSQL API call
    int affectedRows() {
        return cast(int) mysql_affected_rows(mysql);
    }

    override ResultSet queryImpl(string sql, Variant[] args...) {
        sql = escapedVariants(this, sql, args);

        enforceEx!(DatabaseException)(
            !mysql_query(mysql, toCstring(sql)),
        error() ~ " :::: " ~ sql);

        return new MysqlResult(mysql_store_result(mysql), sql);
    }

/+


    struct Result {
        private Result* heaped() {
            auto r = new Result(result, sql, false);

            r.tupleof = this.tupleof;

            this.itemsTotal = 0;
            this.result = null;

            return r;
        }

        this(MYSQL_RES* r, string sql, bool prime = true) {
            result = r;
            itemsTotal = length;
            itemsUsed = 0;
            this.sql = sql;
            // prime it here
            if(prime && itemsTotal)
                fetchNext();
        }

        string sql;

        ~this() {
            if(result !is null)
            mysql_free_result(result);
        }

        /+
        string[string][] fetchAssoc() {

        }
        +/

        ResultByAssoc byAssoc() {
            return ResultByAssoc(&this);
        }

        ResultByStruct!(T) byStruct(T)() {
            return ResultByStruct!(T)(&this);
        }

        string[] fieldNames() {
            int numFields = mysql_num_fields(result);
            auto fields = mysql_fetch_fields(result);

            string[] names;
            for(int i = 0; i < numFields; i++) {
                names ~= fromCstring(fields[i].name);
            }

            return names;
        }

        MYSQL_FIELD[] fields() {
            int numFields = mysql_num_fields(result);
            auto fields = mysql_fetch_fields(result);

            MYSQL_FIELD[] ret;
            for(int i = 0; i < numFields; i++) {
                ret ~= fields[i];
            }

            return ret;
        }

        ulong length() {
            if(result is null)
                return 0;
            return mysql_num_rows(result);
        }

        bool empty() {
            return itemsUsed == itemsTotal;
        }

        Row front() {
            return row;
        }

        void popFront() {
            itemsUsed++;
            if(itemsUsed < itemsTotal) {
                fetchNext();
            }
        }

        void fetchNext() {
            auto r = mysql_fetch_row(result);
            uint numFields = mysql_num_fields(result);
            uint* lengths = mysql_fetch_lengths(result);
            row.length = 0;
            // potential FIXME: not really binary safe

            columnIsNull.length = numFields;
            for(int a = 0; a < numFields; a++) {
                if(*(r+a) is null) {
                    row ~= null;
                    columnIsNull[a] = true;
                } else {
                    row ~= fromCstring(*(r+a), *(lengths + a));
                    columnIsNull[a] = false;
                }
            }
        }

        @disable this(this) {}
        private MYSQL_RES* result;

        ulong itemsTotal;
        ulong itemsUsed;

        alias string[] Row;

        Row row;
        bool[] columnIsNull; // FIXME: should be part of the row
    }
+/
  private:
    MYSQL* mysql;
}

struct ResultByDataObject(ObjType) if (is(ObjType : DataObject)) {
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

    MysqlResult result;
    Mysql mysql;
}


// FIXME: this should work generically with all database types and them moved to database.d
Ret queryOneRow(Ret = Row, DB, string file = __FILE__, size_t line = __LINE__, T...)(DB db, string sql, T t) if(
    (is(DB : Database))
    // && (is(Ret == Row) || is(Ret : DataObject)))
    )
{
    static if(is(Ret : DataObject) && is(DB == Mysql)) {
        auto res = db.queryDataObject!Ret(sql, t);
        if(res.empty)
            throw new EmptyResultException("result was empty", file, line);
        return res.front;
    } else static if(is(Ret == Row)) {
        auto res = db.query(sql, t);
        if(res.empty)
            throw new EmptyResultException("result was empty", file, line);
        return res.front;
    } else static assert(0, "Unsupported single row query return value, " ~ Ret.stringof);
}

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

