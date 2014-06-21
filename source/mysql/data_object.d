module mysql.data_object;

import std.string;
import mysql.database;

/*
    This is like a result set


    DataObject res = [...];

    res.name = "Something";

    res.commit; // runs the actual update or insert


    res = new DataObject(fields, tables







    when doing a select, we need to figure out all the tables and modify the query to include the ids we need


    search for FROM and JOIN
    the next token is the table name

    right before the FROM, add the ids of each table


    given:
        SELECT name, phone FROM customers LEFT JOIN phones ON customer.id = phones.cust_id

    we want:
        SELECT name, phone, customers.id AS id_from_customers, phones.id AS id_from_phones FROM customers LEFT JOIN phones ON customer.id[...];

*/

mixin template DataObjectConstructors() {
    this(Database db, string[string] res, Tuple!(string, string)[string] mappings) {
        super(db, res, mappings);
    }
}

string yield(string what) { return `if(auto result = dg(`~what~`)) return result;`; }

import std.typecons;
import std.json; // for json value making

class DataObject {
    // lets you just free-form set fields, assuming they all come from the given table
    // note it doesn't try to handle joins for new rows. you've gotta do that yourself
    this(Database db, string table) {
        assert(db !is null);
        this.db = db;
        this.table = table;

        mode = UpdateOrInsertMode.CheckForMe;
    }

    JSONValue makeJsonValue() {
        JSONValue val;
        JSONValue[string] valo;
        //val.type = JSON_TYPE.OBJECT;
        foreach(k, v; fields) {
            JSONValue s;
            //s.type = JSON_TYPE.STRING;
            s.str = v;
            valo[k] = s;
            //val.object[k] = s;
        }
        val = valo;
        return val;
    }

    this(Database db, string[string] res, Tuple!(string, string)[string] mappings) {
        this.db = db;
        this.mappings = mappings;
        this.fields = res;

        mode = UpdateOrInsertMode.AlwaysUpdate;
    }

    string table;
    //     table,  column  [alias]
    Tuple!(string, string)[string] mappings;

    // value [field] [table]
    string[string][string] multiTableKeys; // note this is not set internally tight now
                        // but it can be set manually to do multi table mappings for automatic update


    string opDispatch(string field, string file = __FILE__, size_t line = __LINE__)()
        if((field.length < 8 || field[0..8] != "id_from_") && field != "popFront")
    {
        if(field !in fields)
            throw new Exception("no such field " ~ field, file, line);

        return fields[field];
    }

    string opDispatch(string field, T)(T t)
        if((field.length < 8 || field[0..8] != "id_from_") && field != "popFront")
    {
        static if(__traits(compiles, t is null)) {
            if(t is null)
                setImpl(field, null);
            else
                setImpl(field, to!string(t));
        } else
            setImpl(field, to!string(t));

        return fields[field];
    }


    // vararg hack so property assignment works right, even with null
    version(none)
    string opDispatch(string field, string file = __FILE__, size_t line = __LINE__)(...)
        if((field.length < 8 || field[0..8] != "id_from_") && field != "popFront")
    {
        if(_arguments.length == 0) {
            if(field !in fields)
                throw new Exception("no such field " ~ field, file, line);

            return fields[field];
        } else if(_arguments.length == 1) {
            auto arg = _arguments[0];

            string a;
            if(arg == typeid(string) || arg == typeid(immutable(string)) || arg == typeid(const(immutable(char)[]))) {
                a = va_arg!(string)(_argptr);
            } else if (arg == typeid(int) || arg == typeid(immutable(int)) || arg == typeid(const(int))) {
                auto e = va_arg!(int)(_argptr);
                a = to!string(e);
            } else if (arg == typeid(char) || arg == typeid(immutable(char))) {
                auto e = va_arg!(char)(_argptr);
                a = to!string(e);
            } else if (arg == typeid(long) || arg == typeid(const(long)) || arg == typeid(immutable(long))) {
                auto e = va_arg!(long)(_argptr);
                a = to!string(e);
            } else if (arg == typeid(null)) {
                a = null;
            } else assert(0, "invalid type " ~ arg.toString );


            auto setTo = a;
            setImpl(field, setTo);

            return setTo;

        } else assert(0, "too many arguments");

        assert(0); // should never be reached
    }

    private void setImpl(string field, string value) {
        if(field in fields) {
            if(fields[field] != value)
                changed[field] = true;
        } else {
            changed[field] = true;
        }

        fields[field] = value;
    }

    public void setWithoutChange(string field, string value) {
        fields[field] = value;
    }

    int opApply(int delegate(ref string) dg) {
        foreach(a; fields)
            mixin(yield("a"));

        return 0;
    }

    int opApply(int delegate(ref string, ref string) dg) {
        foreach(a, b; fields)
            mixin(yield("a, b"));

        return 0;
    }


    string opIndex(string field, string file = __FILE__, size_t line = __LINE__) {
        if(field !in fields)
            throw new DatabaseException("No such field in data object: " ~ field, file, line);
        return fields[field];
    }

    string opIndexAssign(string value, string field) {
        setImpl(field, value);
        return value;
    }

    string* opBinary(string op)(string key)  if(op == "in") {
        return key in fields;
    }

    string[string] fields;
    bool[string] changed;

    void commitChanges() {
        commitChanges(cast(string) null, null);
    }

    void commitChanges(string key, string keyField) {
        commitChanges(key is null ? null : [key], keyField is null ? null : [keyField]);
    }

    void commitChanges(string[] keys, string[] keyFields = null) {
        string[string][string] toUpdate;
        int updateCount = 0;
        foreach(field, c; changed) {
            if(c) {
                string tbl, col;
                if(mappings is null) {
                    tbl = this.table;
                    col = field;
                } else {
                    if(field !in mappings)
                        assert(0, "no such mapping for " ~ field);
                    auto m = mappings[field];
                    tbl = m[0];
                    col = m[1];
                }

                toUpdate[tbl][col] = fields[field];
                updateCount++;
            }
        }

        if(updateCount) {
            db.startTransaction();
            scope(success) db.query("COMMIT");
            scope(failure) db.query("ROLLBACK");

            foreach(tbl, values; toUpdate) {
                string where, keyFieldToPass;

                if(keys is null) {
                    keys = [null];
                }

                if(multiTableKeys is null || tbl !in multiTableKeys)
                foreach(i, key; keys) {
                    string keyField;

                    if(key is null) {
                        key = "id_from_" ~ tbl;
                        if(key !in fields)
                            key = "id";
                    }

                    if(i >= keyFields.length || keyFields[i] is null) {
                        if(key == "id_from_" ~ tbl)
                            keyField = "id";
                        else
                            keyField = key;
                    } else {
                        keyField = keyFields[i];
                    }


                    if(where.length)
                        where ~= " AND ";

                    auto f = key in fields ? fields[key] : null;
                    if(f is null)
                        where ~= keyField ~ " = NULL";
                    else
                        where ~= keyField ~ " = '"~db.escape(f)~"'" ;
                    if(keyFieldToPass.length)
                        keyFieldToPass ~= ", ";

                    keyFieldToPass ~= keyField;
                }
                else {
                    foreach(keyField, v; multiTableKeys[tbl]) {
                        if(where.length)
                            where ~= " AND ";

                        where ~= keyField ~ " = '"~db.escape(v)~"'" ;
                        if(keyFieldToPass.length)
                            keyFieldToPass ~= ", ";

                        keyFieldToPass ~= keyField;
                    }
                }



                updateOrInsert(db, tbl, values, where, mode, keyFieldToPass);
            }

            changed = null;
        }
    }

    void commitDelete() {
        if(mode == UpdateOrInsertMode.AlwaysInsert)
            throw new Exception("Cannot delete an item not in the database");

        assert(table.length); // FIXME, should work with fancy items too

        // FIXME: escaping and primary key questions
        db.query("DELETE FROM " ~ table ~ " WHERE id = '" ~ db.escape(fields["id"]) ~ "'");
    }

    string getAlias(string table, string column) {
        string ali;
        if(mappings is null) {
            if(this.table is null) {
                mappings[column] = tuple(table, column);
                return column;
            } else {
                assert(table == this.table);
                ali = column;
            }
        } else {
            foreach(a, what; mappings)
                if(what[0] == table && what[1] == column
                  && a.indexOf("id_from_") == -1) {
                    ali = a;
                    break;
                }
        }

        return ali;
    }

    void set(string table, string column, string value) {
        string ali = getAlias(table, column);
        //assert(ali in fields);
        setImpl(ali, value);
    }

    string select(string table, string column) {
        string ali = getAlias(table, column);
        //assert(ali in fields);
        if(ali in fields)
            return fields[ali];
        return null;
    }

    DataObject addNew() {
        auto n = new DataObject(db, null);

        n.db = this.db;
        n.table = this.table;
        n.mappings = this.mappings;

        foreach(k, v; this.fields)
            if(k.indexOf("id_from_") == -1)
                n.fields[k] = v;
            else
                n.fields[k] = null; // don't copy ids

        n.mode = UpdateOrInsertMode.AlwaysInsert;

        return n;
    }

    Database db;
    UpdateOrInsertMode mode;
}

/**
    You can subclass DataObject if you want to
    get some compile time checks or better types.

    You'll want to disable opDispatch, then forward your
    properties to the super opDispatch.
*/

/*mixin*/ string DataObjectField(T, string table, string column, string aliasAs = null)() {
    string aliasAs_;
    if(aliasAs is null)
        aliasAs_ = column;
    else
        aliasAs_ = aliasAs;
    return `
        @property void `~aliasAs_~`(`~T.stringof~` setTo) {
            super.set("`~table~`", "`~column~`", to!string(setTo));
        }

        @property `~T.stringof~` `~aliasAs_~` () {
            return to!(`~T.stringof~`)(super.select("`~table~`", "`~column~`"));
        }
    `;
}

mixin template StrictDataObject() {
    // disable opdispatch
    string opDispatch(string name)(...) if (0) {}
}


string createDataObjectFieldsFromAlias(string table, fieldsToUse)() {
    string ret;

    fieldsToUse f;
    foreach(member; __traits(allMembers, fieldsToUse)) {
        ret ~= DataObjectField!(typeof(__traits(getMember, f, member)), table, member);
    }

    return ret;
}


/**
    This creates an editable data object out of a simple struct.

    struct MyFields {
        int id;
        string name;
    }

    alias SimpleDataObject!("my_table", MyFields) User;


    User a = new User(db);

    a.id = 30;
    a.name = "hello";
    a.commitChanges(); // tries an update or insert on the my_table table


    Unlike the base DataObject class, this template provides compile time
    checking for types and names, based on the struct you pass in:

    a.id = "aa"; // compile error

    a.notAField; // compile error
*/
class SimpleDataObject(string tableToUse, fieldsToUse) : DataObject {
    mixin StrictDataObject!();

    mixin(createDataObjectFieldsFromAlias!(tableToUse, fieldsToUse)());

    this(Database db) {
        super(db, tableToUse);
    }
}