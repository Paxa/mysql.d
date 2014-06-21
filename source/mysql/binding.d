module mysql.binding;

import core.stdc.config;
import std.string;
import std.array;

auto cstr2dstr(inout(char)* cstr, uint str_size) {
    import core.stdc.string: strlen;
    return cstr ? cstr[0 .. strlen(cstr)] : "";
}

cstring toCstring(string c) {
    return cast(cstring) toStringz(c);
}

string fromCstring(cstring c, int len = -1) {
    string ret;
    if (c is null)
        return null;
    if (len == 0)
        return "";
    if (len == -1) {
        auto iterator = c;
        while(*iterator)
            iterator++;

        // note they are both byte pointers, so this is sane
        len = cast(int) iterator - cast(int) c;
        assert(len >= 0);
    }

    ret = cast(string) (c[0 .. len].idup);

    return ret;
}

version(Windows) {
    pragma(lib, "libmysql");
} else {
    pragma(lib, "mysqlclient");
}

extern(System) {
    struct MYSQL;

    struct MYSQL_RES {
        ulong  row_count;
        MYSQL_FIELD     *fields;
        MYSQL_DATA      *data;
        MYSQL_ROWS      *data_cursor;
        ulong           *lengths;        /* column lengths of current row */
        MYSQL           *handle;        /* for unbuffered reads */
        //const struct st_mysql_methods *methods;
        MYSQL_ROW       row;            /* If unbuffered read */
        MYSQL_ROW       current_row;    /* buffer to current row */
        ///MEM_ROOT     field_alloc;
        uint            field_count, current_field;
        char            eof;            /* Used by mysql_fetch_row */
        /* mysql_stmt_close() had to cancel this result */
        char            unbuffered_fetch_cancelled;
        void            *extension;
    }

    struct MYSQL_ROWS {
        //struct st_mysql_rows *next;        /* list of rows */
        MYSQL_ROW data;
        ulong length;
    }

    struct MYSQL_DATA {
        MYSQL_ROWS *data;
        //struct embedded_query_result *embedded_info;
        //MEM_ROOT alloc;
        ulong rows;
        uint fields;
        /* extra info for embedded library */
        void *extension;
    }

    /* typedef */ alias const(ubyte)* cstring;

    struct MYSQL_FIELD {
        cstring name;                 /* Name of column */
        cstring org_name;             /* Original column name, if an alias */
        cstring table;                /* Table of column if column was a field */
        cstring org_table;            /* Org table name, if table was an alias */
        cstring db;                   /* Database for table */
        cstring catalog;          /* Catalog for table */
        cstring def;                  /* Default value (set by mysql_list_fields) */
        ulong length;       /* Width of column (create length) */
        ulong max_length;   /* Max width for selected set */
        uint name_length;
        uint org_name_length;
        uint table_length;
        uint org_table_length;
        uint db_length;
        uint catalog_length;
        uint def_length;
        uint flags;         /* Div flags */
        uint decimals;      /* Number of decimals in field */
        uint charsetnr;     /* Character set */
        uint type; /* Type of field. See mysql_com.h for types */
        // type is actually an enum btw
        void* extension;
    }

    alias char** MYSQL_ROW;

    cstring mysql_get_client_info();
    ulong mysql_get_client_version();

    MYSQL* mysql_init(MYSQL*);
    uint mysql_errno(MYSQL*);
    cstring mysql_error(MYSQL*);

    MYSQL* mysql_real_connect(MYSQL*, cstring, cstring, cstring, cstring, uint, cstring, c_ulong);
    int mysql_select_db(MYSQL*, cstring);

    int mysql_query(MYSQL*, cstring);

    void mysql_close(MYSQL*);
    int mysql_ping(MYSQL *mysql);

    ulong mysql_num_rows(MYSQL_RES*);
    uint mysql_num_fields(MYSQL_RES*);
    bool mysql_eof(MYSQL_RES*);

    ulong mysql_affected_rows(MYSQL*);
    ulong mysql_insert_id(MYSQL*);

    MYSQL_RES* mysql_store_result(MYSQL*);
    MYSQL_RES* mysql_use_result(MYSQL*);

    MYSQL_ROW mysql_fetch_row(MYSQL_RES *);
    uint* mysql_fetch_lengths(MYSQL_RES*);
    MYSQL_FIELD* mysql_fetch_field(MYSQL_RES*);
    MYSQL_FIELD* mysql_fetch_fields(MYSQL_RES*);
    MYSQL_FIELD mysql_fetch_field_direct(MYSQL_RES*, uint);

    uint mysql_real_escape_string(MYSQL*, ubyte* to, cstring from, uint length);

    void mysql_free_result(MYSQL_RES*);
}