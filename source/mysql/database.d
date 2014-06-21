module mysql.database;

public import std.variant;
import std.string;
import std.stdio;

import core.vararg;

interface Database {
    /// Actually implements the query for the database. The query() method
    /// below might be easier to use.
    ResultSet queryImpl(string sql, Variant[] args...);

    /// Escapes data for inclusion into an sql string literal
    string escape(string sqlData);

    /// query to start a transaction, only here because sqlite is apparently different in syntax...
    void startTransaction();

    // FIXME: this would be better as a template, but can't because it is an interface

    /// Just executes a query. It supports placeholders for parameters
    /// by using ? in the sql string. NOTE: it only accepts string, int, long, and null types.
    /// Others will fail runtime asserts.
    final ResultSet query(string sql, ...) {
        Variant[] args;
        foreach(arg; _arguments) {
            string a;
            if(arg == typeid(string) || arg == typeid(immutable(string)) || arg == typeid(const(string)))
                a = va_arg!string(_argptr);
            else if (arg == typeid(int) || arg == typeid(immutable(int)) || arg == typeid(const(int))) {
                auto e = va_arg!int(_argptr);
                a = to!string(e);
            } else if (arg == typeid(uint) || arg == typeid(immutable(uint)) || arg == typeid(const(uint))) {
                auto e = va_arg!uint(_argptr);
                a = to!string(e);
            } else if (arg == typeid(immutable(char))) {
                auto e = va_arg!char(_argptr);
                a = to!string(e);
            } else if (arg == typeid(long) || arg == typeid(const(long)) || arg == typeid(immutable(long))) {
                auto e = va_arg!long(_argptr);
                a = to!string(e);
            } else if (arg == typeid(ulong) || arg == typeid(const(ulong)) || arg == typeid(immutable(ulong))) {
                auto e = va_arg!ulong(_argptr);
                a = to!string(e);
            } else if (arg == typeid(null)) {
                a = null;
            } else assert(0, "invalid type " ~ arg.toString() );

            args ~= Variant(a);
        }

        return queryImpl(sql, args);
    }
}

/*
Ret queryOneColumn(Ret, string file = __FILE__, size_t line = __LINE__, T...)(Database db, string sql, T t) {
    auto res = db.query(sql, t);
    if(res.empty)
        throw new Exception("no row in result", file, line);
    auto row = res.front;
    return to!Ret(row[0]);
}
*/

struct Query {
    ResultSet result;
    this(T...)(Database db, string sql, T t) if(T.length!=1 || !is(T[0]==Variant[])) {
        result = db.query(sql, t);
    }
    // Version for dynamic generation of args: (Needs to be a template for coexistence with other constructor.
    this(T...)(Database db, string sql, T args) if (T.length==1 && is(T[0] == Variant[])) {
        result = db.queryImpl(sql, args);
    }

    int opApply(T)(T dg) if(is(T == delegate)) {
        import std.traits;
        foreach(row; result) {
            ParameterTypeTuple!dg tuple;

            foreach(i, item; tuple) {
                tuple[i] = to!(typeof(item))(row[i]);
            }

            if(auto result = dg(tuple))
                return result;
        }

        return 0;
    }
}

struct Row {
    package string[] row;
    package ResultSet resultSet;

    string opIndex(size_t idx, string file = __FILE__, int line = __LINE__) {
        if(idx >= row.length)
            throw new Exception(text("index ", idx, " is out of bounds on result"), file, line);
        return row[idx];
    }

    string opIndex(string name, string file = __FILE__, int line = __LINE__) {
        auto idx = resultSet.getFieldIndex(name);
        if(idx >= row.length)
            throw new Exception(text("no field ", name, " in result"), file, line);
        return row[idx];
    }

    string toString() {
        return to!string(row);
    }

    string[string] toAA() {
        string[string] a;

        string[] fn = resultSet.fieldNames();

        foreach(i, r; row)
            a[fn[i]] = r;

        return a;
    }

    int opApply(int delegate(ref string, ref string) dg) {
        foreach(a, b; toAA())
            mixin(yield("a, b"));

        return 0;
    }



    string[] toStringArray() {
        return row;
    }
}
import std.conv;

interface ResultSet {
    // name for associative array to result index
    int getFieldIndex(string field);
    string[] fieldNames();

    // this is a range that can offer other ranges to access it
    bool empty() @property;
    Row front() @property;
    void popFront() ;
    int length() @property;

    /* deprecated */ final ResultSet byAssoc() { return this; }
}

class DatabaseException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}



abstract class SqlBuilder { }

/// WARNING: this is as susceptible to SQL injections as you would be writing it out by hand
class SelectBuilder : SqlBuilder {
    string[] fields;
    string table;
    string[] joins;
    string[] wheres;
    string[] orderBys;
    string[] groupBys;

    int limit;
    int limitStart;

    Variant[string] vars;
    void setVariable(T)(string name, T value) {
        vars[name] = Variant(value);
    }

    Database db;
    this(Database db = null) {
        this.db = db;
    }

    /*
        It would be nice to put variables right here in the builder

        ?name

        will prolly be the syntax, and we'll do a Variant[string] of them.

        Anything not translated here will of course be in the ending string too
    */

    SelectBuilder cloned() {
        auto s = new SelectBuilder(this.db);
        s.fields = this.fields.dup;
        s.table = this.table;
        s.joins = this.joins.dup;
        s.wheres = this.wheres.dup;
        s.orderBys = this.orderBys.dup;
        s.groupBys = this.groupBys.dup;
        s.limit = this.limit;
        s.limitStart = this.limitStart;

        foreach(k, v; this.vars)
            s.vars[k] = v;

        return s;
    }

    override string toString() {
        string sql = "SELECT ";

        // the fields first
        {
            bool outputted = false;
            foreach(field; fields) {
                if(outputted)
                    sql ~= ", ";
                else
                    outputted = true;

                sql ~= field; // "`" ~ field ~ "`";
            }
        }

        sql ~= " FROM " ~ table;

        if(joins.length) {
            foreach(join; joins)
                sql ~= " " ~ join;
        }

        if(wheres.length) {
            bool outputted = false;
            sql ~= " WHERE ";
            foreach(w; wheres) {
                if(outputted)
                    sql ~= " AND ";
                else
                    outputted = true;
                sql ~= "(" ~ w ~ ")";
            }
        }

        if(groupBys.length) {
            bool outputted = false;
            sql ~= " GROUP BY ";
            foreach(o; groupBys) {
                if(outputted)
                    sql ~= ", ";
                else
                    outputted = true;
                sql ~= o;
            }
        }
        
        if(orderBys.length) {
            bool outputted = false;
            sql ~= " ORDER BY ";
            foreach(o; orderBys) {
                if(outputted)
                    sql ~= ", ";
                else
                    outputted = true;
                sql ~= o;
            }
        }

        if(limit) {
            sql ~= " LIMIT ";
            if(limitStart)
                sql ~= to!string(limitStart) ~ ", ";
            sql ~= to!string(limit);
        }

        if(db is null)
            return sql;

        return escapedVariants(db, sql, vars);
    }
}


// /////////////////////sql//////////////////////////////////


// used in the internal placeholder thing
string toSql(Database db, Variant a) {
    auto v = a.peek!(void*);
    if(v && (*v is null))
        return "NULL";
    else {
        string str = to!string(a);
        return '\'' ~ db.escape(str) ~ '\'';
    }

    assert(0);
}

// just for convenience; "str".toSql(db);
string toSql(string s, Database db) {
    if(s is null)
        return "NULL";
    return '\'' ~ db.escape(s) ~ '\'';
}

string toSql(long s, Database db) {
    return to!string(s);
}

string escapedVariants(Database db, in string sql, Variant[string] t) {
    if(t.keys.length <= 0 || sql.indexOf("?") == -1) {
        return sql;
    }

    string fixedup;
    int currentStart = 0;
// FIXME: let's make ?? render as ? so we have some escaping capability
    foreach(int i, dchar c; sql) {
        if(c == '?') {
            fixedup ~= sql[currentStart .. i];

            int idxStart = i + 1;
            int idxLength;

            bool isFirst = true;

            while(idxStart + idxLength < sql.length) {
                char C = sql[idxStart + idxLength];

                if((C >= 'a' && C <= 'z') || (C >= 'A' && C <= 'Z') || C == '_' || (!isFirst && C >= '0' && C <= '9'))
                    idxLength++;
                else
                    break;

                isFirst = false;
            }

            auto idx = sql[idxStart .. idxStart + idxLength];

            if(idx in t) {
                fixedup ~= toSql(db, t[idx]);
                currentStart = idxStart + idxLength;
            } else {
                // just leave it there, it might be done on another layer
                currentStart = i;
            }
        }
    }

    fixedup ~= sql[currentStart .. $];

    return fixedup;
}

// TODO: cut this out
/// Note: ?n params are zero based!
string escapedVariants(Database db, in string sql, Variant[] t) {
// FIXME: let's make ?? render as ? so we have some escaping capability
    // if nothing to escape or nothing to escape with, don't bother
    if(t.length > 0 && sql.indexOf("?") != -1) {
        string fixedup;
        int currentIndex;
        int currentStart = 0;
        foreach(int i, dchar c; sql) {
            if(c == '?') {
                fixedup ~= sql[currentStart .. i];

                int idx = -1;
                currentStart = i + 1;
                if((i + 1) < sql.length) {
                    auto n = sql[i + 1];
                    if(n >= '0' && n <= '9') {
                        currentStart = i + 2;
                        idx = n - '0';
                    }
                }
                if(idx == -1) {
                    idx = currentIndex;
                    currentIndex++;
                }

                if(idx < 0 || idx >= t.length)
                    throw new Exception("SQL Parameter index is out of bounds: " ~ to!string(idx) ~ " at `"~sql[0 .. i]~"`");

                fixedup ~= toSql(db, t[idx]);
            }
        }

        fixedup ~= sql[currentStart .. $];

        return fixedup;
        /*
        string fixedup;
        int pos = 0;


        void escAndAdd(string str, int q) {
            fixedup ~= sql[pos..q] ~ '\'' ~ db.escape(str) ~ '\'';

        }

        foreach(a; t) {
            int q = sql[pos..$].indexOf("?");
            if(q == -1)
                break;
            q += pos;

            auto v = a.peek!(void*);
            if(v && (*v is null))
                fixedup  ~= sql[pos..q] ~ "NULL";
            else {
                string str = to!string(a);
                escAndAdd(str, q);
            }

            pos = q+1;
        }

        fixedup ~= sql[pos..$];

        sql = fixedup;
        */
    }

    return sql;
}


enum UpdateOrInsertMode {
    CheckForMe,
    AlwaysUpdate,
    AlwaysInsert
}


// BIG FIXME: this should really use prepared statements
int updateOrInsert(Database db, string table, string[string] values, string where, UpdateOrInsertMode mode = UpdateOrInsertMode.CheckForMe, string key = "id") {
    bool insert = false;

    final switch(mode) {
        case UpdateOrInsertMode.CheckForMe:
            auto res = db.query("SELECT "~key~" FROM `"~db.escape(table)~"` WHERE " ~ where);
            insert = res.empty;

        break;
        case UpdateOrInsertMode.AlwaysInsert:
            insert = true;
        break;
        case UpdateOrInsertMode.AlwaysUpdate:
            insert = false;
        break;
    }


    if(insert) {
        string insertSql = "INSERT INTO `" ~ db.escape(table) ~ "` ";

        bool outputted = false;
        string vs, cs;
        foreach(column, value; values) {
            if(column is null)
                continue;
            if(outputted) {
                vs ~= ", ";
                cs ~= ", ";
            } else
                outputted = true;

            //cs ~= "`" ~ db.escape(column) ~ "`";
            cs ~= "`" ~ column ~ "`"; // FIXME: possible insecure
            if(value is null)
                vs ~= "NULL";
            else
                vs ~= "'" ~ db.escape(value) ~ "'";
        }

        if(!outputted)
            return 0;


        insertSql ~= "(" ~ cs ~ ")";
        insertSql ~= " VALUES ";
        insertSql ~= "(" ~ vs ~ ")";

        db.query(insertSql);

        return 0; // db.lastInsertId;
    } else {
        string updateSql = "UPDATE `"~db.escape(table)~"` SET ";

        bool outputted = false;
        foreach(column, value; values) {
            if(column is null)
                continue;
            if(outputted)
                updateSql ~= ", ";
            else
                outputted = true;

            if(value is null)
                updateSql ~= "`" ~ db.escape(column) ~ "` = NULL";
            else
                updateSql ~= "`" ~ db.escape(column) ~ "` = '" ~ db.escape(value) ~ "'";
        }

        if(!outputted)
            return 0;

        updateSql ~= " WHERE " ~ where;

        db.query(updateSql);
        return 0;
    }
}





string fixupSqlForDataObjectUse(string sql, string[string] keyMapping = null) {

    string[] tableNames;

    string piece = sql;
    sizediff_t idx;
    while((idx = piece.indexOf("JOIN")) != -1) {
        auto start = idx + 5;
        auto i = start;
        while(piece[i] != ' ' && piece[i] != '\n' && piece[i] != '\t' && piece[i] != ',')
            i++;
        auto end = i;

        tableNames ~= strip(piece[start..end]);

        piece = piece[end..$];
    }

    idx = sql.indexOf("FROM");
    if(idx != -1) {
        auto start = idx + 5;
        auto i = start;
        start = i;
        while(i < sql.length && !(sql[i] > 'A' && sql[i] <= 'Z')) // if not uppercase, except for A (for AS) to avoid SQL keywords (hack)
            i++;

        auto from = sql[start..i];
        auto pieces = from.split(",");
        foreach(p; pieces) {
            p = p.strip();
            start = 0;
            i = 0;
            while(i < p.length && p[i] != ' ' && p[i] != '\n' && p[i] != '\t' && p[i] != ',')
                i++;

            tableNames ~= strip(p[start..i]);
        }

        string sqlToAdd;
        foreach(tbl; tableNames) {
            if(tbl.length) {
                string keyName = "id";
                if(tbl in keyMapping)
                    keyName = keyMapping[tbl];
                sqlToAdd ~= ", " ~ tbl ~ "." ~ keyName ~ " AS " ~ "id_from_" ~ tbl;
            }
        }

        sqlToAdd ~= " ";

        sql = sql[0..idx] ~ sqlToAdd ~ sql[idx..$];
    }

    return sql;
}

import mysql.data_object;

/**
    Given some SQL, it finds the CREATE TABLE
    instruction for the given tableName.
    (this is so it can find one entry from
    a file with several SQL commands. But it
    may break on a complex file, so try to only
    feed it simple sql files.)

    From that, it pulls out the members to create a
    simple struct based on it.

    It's not terribly smart, so it will probably
    break on complex tables.

    Data types handled:
        INTEGER, SMALLINT, MEDIUMINT -> D's int
        TINYINT -> D's bool
        BIGINT -> D's long
        TEXT, VARCHAR -> D's string
        FLOAT, DOUBLE -> D's double

    It also reads DEFAULT values to pass to D, except for NULL.
    It ignores any length restrictions.

    Bugs:
        Skips all constraints
        Doesn't handle nullable fields, except with strings
        It only handles SQL keywords if they are all caps

    This, when combined with SimpleDataObject!(),
    can automatically create usable D classes from
    SQL input.
*/
struct StructFromCreateTable(string sql, string tableName) {
    mixin(getCreateTable(sql, tableName));
}

string getCreateTable(string sql, string tableName) {
   skip:
    while(readWord(sql) != "CREATE") {}

    assert(readWord(sql) == "TABLE");

    if(readWord(sql) != tableName)
        goto skip;

    assert(readWord(sql) == "(");

    int state;
    int parens;

    struct Field {
        string name;
        string type;
        string defaultValue;
    }
    Field*[] fields;

    string word = readWord(sql);
    Field* current = new Field(); // well, this is interesting... under new DMD, not using new breaks it in CTFE because it overwrites the one entry!
    while(word != ")" || parens) {
        if(word == ")") {
            parens --;
            word = readWord(sql);
            continue;
        }
        if(word == "(") {
            parens ++;
            word = readWord(sql);
            continue;
        }
        switch(state) {
            default: assert(0);
            case 0:
                if(word[0] >= 'A' && word[0] <= 'Z') {
                state = 4;
                break; // we want to skip this since it starts with a keyword (we hope)
            }
            current.name = word;
            state = 1;
            break;
            case 1:
                current.type ~= word;
            state = 2;
            break;
            case 2:
                if(word == "DEFAULT")
                state = 3;
            else if (word == ",") {
                fields ~= current;
                current = new Field();
                state = 0; // next
            }
            break;
            case 3:
                current.defaultValue = word;
            state = 2; // back to skipping
            break;
            case 4:
                if(word == ",")
                state = 0;
        }

        word = readWord(sql);
    }

    if(current.name !is null)
        fields ~= current;


    string structCode;
    foreach(field; fields) {
        structCode ~= "\t";

        switch(field.type) {
            case "INTEGER":
            case "SMALLINT":
            case "MEDIUMINT":
                structCode ~= "int";
            break;
            case "BOOLEAN":
            case "TINYINT":
                structCode ~= "bool";
            break;
            case "BIGINT":
                structCode ~= "long";
            break;
            case "CHAR":
            case "char":
            case "VARCHAR":
            case "varchar":
            case "TEXT":
            case "text":
                structCode ~= "string";
            break;
            case "FLOAT":
            case "DOUBLE":
                structCode ~= "double";
            break;
            default:
                assert(0, "unknown type " ~ field.type ~ " for " ~ field.name);
        }

        structCode ~= " ";
        structCode ~= field.name;

        if(field.defaultValue !is null) {
            structCode ~= " = " ~ field.defaultValue;
        }

        structCode ~= ";\n";
    }

    return structCode;
}

string readWord(ref string src) {
   reset:
    while(src[0] == ' ' || src[0] == '\t' || src[0] == '\n')
        src = src[1..$];
    if(src.length >= 2 && src[0] == '-' && src[1] == '-') { // a comment, skip it
        while(src[0] != '\n')
            src = src[1..$];
        goto reset;
    }

    int start, pos;
    if(src[0] == '`') {
        src = src[1..$];
        while(src[pos] != '`')
            pos++;
        goto gotit;
    }


    while(
        (src[pos] >= 'A' && src[pos] <= 'Z')
        ||
        (src[pos] >= 'a' && src[pos] <= 'z')
        ||
        (src[pos] >= '0' && src[pos] <= '9')
        ||
        src[pos] == '_'
    )
        pos++;
    gotit:
    if(pos == 0)
        pos = 1;

    string tmp = src[0..pos];

    if(src[pos] == '`')
        pos++; // skip the ending quote;

    src = src[pos..$];

    return tmp;
}

/// Combines StructFromCreateTable and SimpleDataObject into a one-stop template.
/// alias DataObjectFromSqlCreateTable(import("file.sql"), "my_table") MyTable;
template DataObjectFromSqlCreateTable(string sql, string tableName) {
    alias SimpleDataObject!(tableName, StructFromCreateTable!(sql, tableName)) DataObjectFromSqlCreateTable;
}

/+
class MyDataObject : DataObject {
    this() {
        super(new Database("localhost", "root", "pass", "social"), null);
    }

    mixin StrictDataObject!();

    mixin(DataObjectField!(int, "users", "id"));
}

void main() {
    auto a = new MyDataObject;

    a.fields["id"] = "10";

    a.id = 34;

    a.commitChanges;
}
+/

/*
alias DataObjectFromSqlCreateTable!(import("db.sql"), "users") Test;

void main() {
    auto a = new Test(null);

    a.cool = "way";
    a.value = 100;
}
*/

void typeinfoBugWorkaround() {
    assert(0, to!string(typeid(immutable(char[])[immutable(char)[]])));
}
