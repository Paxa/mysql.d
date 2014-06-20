module mysql.mysql_result;

import std.stdio;
import std.exception;

import mysql.binding;
import mysql.database;

class MySqlResult : ResultSet {
    private int[string] mapping;
    public MYSQL_RES* result;

    private int itemsTotal;
    private int itemsUsed;

    string sql;

    this(MYSQL_RES* r, string sql) {
        result = r;
        itemsTotal = length();
        itemsUsed = 0;

        this.sql = sql;

        // prime it
        if(itemsTotal)
            fetchNext();
    }

    ~this() {
        if(result !is null)
            mysql_free_result(result);
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


    override int length() {
        if(result is null)
            return 0;
        return cast(int) mysql_num_rows(result);
    }

    override bool empty() {
        return itemsUsed == itemsTotal;
    }

    override Row front() {
        return row;
    }

    override void popFront() {
        itemsUsed++;
        if(itemsUsed < itemsTotal) {
            fetchNext();
        }
    }

    override int getFieldIndex(string field) {
        if(mapping is null)
            makeFieldMapping();
        debug {
            if(field !in mapping)
                throw new Exception(field ~ " not in result");
        }
        return mapping[field];
    }

    private void makeFieldMapping() {
        int numFields = mysql_num_fields(result);
        auto fields = mysql_fetch_fields(result);

        if(fields is null)
            return;

        for(int i = 0; i < numFields; i++) {
            if(fields[i].name !is null)
                mapping[fromCstring(fields[i].name, fields[i].name_length)] = i;
        }
    }

    private void fetchNext() {
        assert(result);
        auto my_row = mysql_fetch_row(result);
        if(my_row is null)
            throw new Exception("there is no next row");
        uint numFields = mysql_num_fields(result);
        uint* lengths = mysql_fetch_lengths(result);
        string[] row;
        // potential FIXME: not really binary safe

        columnIsNull.length = numFields;
        for(uint numField = 0; numField < numFields; numField++) {
          //writefln("numField %d", numField);
            if (my_row[numField] is null) {
                row ~= null;
                columnIsNull[numField] = true;
            } else {
                row ~= cast(string) cstr2dstr(my_row[numField], lengths[numField]);
                columnIsNull[numField] = false;
            }
        }

        this.row.row = row;
        this.row.resultSet = this;
    }


    override string[] fieldNames() {
        int numFields = mysql_num_fields(result);
        auto fields = mysql_fetch_fields(result);

        string[] names;
        for(int i = 0; i < numFields; i++) {
            names ~= fromCstring(fields[i].name, fields[i].name_length);
        }

        return names;
    }

    bool[] columnIsNull;
    Row row;
}
