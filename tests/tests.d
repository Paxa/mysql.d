public import mysql.mysql;

unittest {
    import mysql.test_config;
    test_mysql_config_env();
    import mysql.mysql_test;
    import mysql.mysql_result_test;
    import mysql.mysql_row_test;
    import mysql.mysql_query_interface_test;
}