module mysql.query_interface;

import mysql.mysql;

import std.variant;
import std.string;
import std.conv;
import core.vararg;

class QueryInterface {
    
    /// Just executes a query. It supports placeholders for parameters
    /// by using ? in the sql string. NOTE: it only accepts string, int, long, byte, and null types.
    /// Others will fail runtime asserts.

    static string makeQuery(Mysql db, string sql, ...) {
        Variant[] args;
        for(int i = 0; i < _arguments.length; i++) {
        //foreach(arg; _arguments) {
            auto arg = _arguments[i];
            string a;
            // STRING
            if(arg == typeid(string) || arg == typeid(immutable(string)) || arg == typeid(const(string))) {
                a = va_arg!string(_argptr);
            // INT
            } else if (arg == typeid(int) || arg == typeid(immutable(int)) || arg == typeid(const(int))) {
                auto e = va_arg!int(_argptr);
                a = to!string(e);
            // UINT
            } else if (arg == typeid(uint) || arg == typeid(immutable(uint)) || arg == typeid(const(uint))) {
                auto e = va_arg!uint(_argptr);
                a = to!string(e);
            // CHAR
            } else if (arg == typeid(immutable(char))) {
                auto e = va_arg!char(_argptr);
                a = to!string(e);
            // LONG
            } else if (arg == typeid(long) || arg == typeid(const(long)) || arg == typeid(immutable(long))) {
                auto e = va_arg!long(_argptr);
                a = to!string(e);
            // ULONG
            } else if (arg == typeid(ulong) || arg == typeid(const(ulong)) || arg == typeid(immutable(ulong))) {
                auto e = va_arg!ulong(_argptr);
                a = to!string(e);
            // UBYTE
            } else if (arg == typeid(ubyte) || arg == typeid(const(ubyte)) || arg == typeid(immutable(ubyte))) {
                auto e = va_arg!ubyte(_argptr);
                a = to!string(e);
            // BYTE
            } else if (arg == typeid(byte) || arg == typeid(const(byte)) || arg == typeid(immutable(byte))) {
                auto e = va_arg!byte(_argptr);
                a = to!string(e);
            // SHORT
            } else if (arg == typeid(short) || arg == typeid(const(short)) || arg == typeid(immutable(short))) {
                auto e = va_arg!short(_argptr);
                a = to!string(e);
            // USHORT
            } else if (arg == typeid(ushort) || arg == typeid(const(ushort)) || arg == typeid(immutable(ushort))) {
                auto e = va_arg!ushort(_argptr);
                a = to!string(e);
            // FLOAT
            } else if (arg == typeid(float) || arg == typeid(const(float)) || arg == typeid(immutable(float))) {
                auto e = va_arg!float(_argptr);
                a = to!string(e);
            // DOUBLE
            } else if (arg == typeid(double) || arg == typeid(const(double)) || arg == typeid(immutable(double))) {
                auto e = va_arg!double(_argptr);
                a = to!string(e);
            // REAL
            } else if (arg == typeid(real) || arg == typeid(const(real)) || arg == typeid(immutable(real))) {
                auto e = va_arg!real(_argptr);
                a = to!string(e);
            // ARRAYS
            // INT[]
            } else if (arg == typeid(int[]) || arg == typeid(immutable(int[])) || arg == typeid(const(int[]))) {
                auto e = va_arg!(int[])(_argptr);
                a = to!(string[])(e).join(", ");
            // UINT[]
            } else if (arg == typeid(uint[]) || arg == typeid(immutable(uint[])) || arg == typeid(const(uint[]))) {
                auto e = va_arg!(uint[])(_argptr);
                a = to!(string[])(e).join(", ");
            // LONG[]
            } else if (arg == typeid(long[]) || arg == typeid(immutable(long[])) || arg == typeid(const(long[]))) {
                auto e = va_arg!(long[])(_argptr);
                a = to!(string[])(e).join(", ");
            // ULONG[]
            } else if (arg == typeid(ulong[]) || arg == typeid(immutable(ulong[])) || arg == typeid(const(ulong[]))) {
                auto e = va_arg!(ulong[])(_argptr);
                a = to!(string[])(e).join(", ");
            // BYTE[]
            } else if (arg == typeid(byte[]) || arg == typeid(immutable(byte[])) || arg == typeid(const(byte[]))) {
                auto e = va_arg!(byte[])(_argptr);
                a = to!(string[])(e).join(", ");
            // UBYTE[]
            } else if (arg == typeid(ubyte[]) || arg == typeid(immutable(ubyte[])) || arg == typeid(const(ubyte[]))) {
                auto e = va_arg!(ubyte[])(_argptr);
                a = to!(string[])(e).join(", ");
            // SHORT[]
            } else if (arg == typeid(short[]) || arg == typeid(immutable(short[])) || arg == typeid(const(short[]))) {
                auto e = va_arg!(short[])(_argptr);
                a = to!(string[])(e).join(", ");
            // USHORT[]
            } else if (arg == typeid(ushort[]) || arg == typeid(immutable(ushort[])) || arg == typeid(const(ushort[]))) {
                auto e = va_arg!(ushort[])(_argptr);
                a = to!(string[])(e).join(", ");
            // FLOAT[]
            } else if (arg == typeid(float[]) || arg == typeid(immutable(float[])) || arg == typeid(const(float[]))) {
                auto e = va_arg!(float[])(_argptr);
                a = to!(string[])(e).join(", ");
            // DOUBLE[]
            } else if (arg == typeid(double[]) || arg == typeid(immutable(double[])) || arg == typeid(const(double[]))) {
                auto e = va_arg!(double[])(_argptr);
                a = to!(string[])(e).join(", ");
            // REAL[]
            } else if (arg == typeid(real[]) || arg == typeid(immutable(real[])) || arg == typeid(const(real[]))) {
                auto e = va_arg!(ushort[])(_argptr);
                a = to!(string[])(e).join(", ");
            // STRING[]
            } else if (arg == typeid(string[]) || arg == typeid(immutable(string[])) || arg == typeid(const(string[]))) {
                auto e = va_arg!(string[])(_argptr);
                string[] escaped;
                foreach(el; e) escaped ~= "'" ~ db.escape(el) ~ "'";
                a = escaped.join(", ");
            // NULL
            } else if (arg == typeid(null)) {
                a = null;
            } else assert(0, "invalid type " ~ arg.toString() );

            args ~= Variant(a);
        }

        return escapedVariants(db, sql, args);
    }

    /*
    static string escaped(T...)(string sql, T t) {
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
    */

    // used in the internal placeholder thing
    static string toSql(Variant a, Mysql db) {
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
    static string toSql(string s, Mysql db) {
        if(s is null) return "NULL";
        return '\'' ~ db.escape(s) ~ '\'';
    }

    static string toSql(long s, Mysql db) {
        return to!string(s);
    }

    static string toSqlName(string s, Mysql db) {
        if(s is null) return "NULL";
        return db.escape(s);
    }

    static string toSqlName(long s, Mysql db) {
        return toSql(s, db);
    }

    static string toSqlName(Variant a, Mysql db) {
        auto v = a.peek!(void*);
        if(v && (*v is null))
            return "NULL";
        else {
            string str = to!string(a);
            return db.escape(str);
        }

        assert(0);
    }

    static string toSqlArray(long s, Mysql db) {
        return toSql(s, db);
    }

    static string toSqlArray(Variant a, Mysql db) {
        auto v = a.peek!(void*);
        if(v && (*v is null))
            return "NULL";
        else {
            return to!string(a);
        }

        assert(0);
    }

    static string escapedVariants(Mysql db, in string sql, Variant[string] t) {
        if(t.keys.length <= 0 || sql.indexOf("?") == -1) {
            return sql;
        }

        string fixedup;
        int currentStart = 0;
    // FIXME: let's make ?? render as ? so we have some escaping capability
        foreach(int i, dchar c; sql) {
            if (c == '?') {
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
                    fixedup ~= toSql(t[idx], db);
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

    /// Note: ?n params are zero based!
    static string escapedVariants(Mysql db, in string sql, Variant[] t) {
        // FIXME: let's make ?? render as ? so we have some escaping capability
        // if nothing to escape or nothing to escape with, don't bother
        if (t.length > 0 && sql.indexOf("?") != -1) {
            string fixedup;
            int currentIndex;
            int currentStart = 0;
            foreach (int i, dchar c; sql) {
                if (c == '?') {
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
                        throw new Exception("SQL Parameter index is out of bounds: " ~ to!string(idx) ~ " at `" ~ sql[0 .. i] ~ "`");

                    if (sql[i - 1] == '`' && sql[i + 1] == '`') {
                        fixedup ~= toSqlName(t[idx], db);
                    } else if (sql[i - 1] == '(' && sql[i + 1] == ')') {
                        fixedup ~= toSqlArray(t[idx], db);
                    } else {
                        fixedup ~= toSql(t[idx], db);
                    }
                }
            }

            fixedup ~= sql[currentStart .. $];

            return fixedup;
        }

        return sql;
    }
}