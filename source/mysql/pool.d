module mysql.pool;

import core.time;
import core.thread;
import std.stdio;
import std.array;
import std.concurrency;
import std.datetime;
import std.algorithm.searching : any;
import std.algorithm.mutation : remove;

import mysql.mysql;

alias ConnectionPool = shared ConnectionProvider;

final class ConnectionProvider
{
    static ConnectionPool getInstance(string host, ushort port, string user, string password, string database,
            string charset = null,
            uint maxConnections = 10, uint initialConnections = 3, uint incrementalConnections = 3,
            uint waitSeconds = 5)
    {
        assert(initialConnections > 0 && incrementalConnections > 0);

        if (_instance is null)
        {
            synchronized(ConnectionProvider.classinfo)
            {
                if (_instance is null)
                {
                    _instance = new ConnectionPool(host, port, user, password, database, charset,
                            maxConnections, initialConnections, incrementalConnections, waitSeconds);
                }
            }
        }

        return _instance;
    }

    private this(string host, ushort port, string user, string password, string database, string charset,
            uint maxConnections, uint initialConnections, uint incrementalConnections, uint waitSeconds) shared
    {
        _pool = cast(shared Tid)spawn(
                new shared Pool(host, port, user, password, database, charset,
                        maxConnections, initialConnections, incrementalConnections, waitSeconds.seconds));
        _waitSeconds = waitSeconds;
        while (!__instantiated) Thread.sleep(0.msecs);
    }

    ~this() shared
    {
        (cast(Tid)_pool).send(new shared Terminate(cast(shared Tid)thisTid));

        L_receive: try
        {
            receive(
                (shared Terminate _t)
                {
                    return;
                }
            );
        }
        catch (OwnerTerminated e)
        {
            if (e.tid != thisTid) goto L_receive;
        }

        __instantiated = false;
    }

    Connection getConnection() shared
    {
        (cast(Tid)_pool).send(new shared RequestConnection(cast(shared Tid)thisTid));
        Connection conn;

        L_receive: try
        {
            receiveTimeout(
                _waitSeconds.seconds,
                (shared ConnenctionHolder holder)
                {
                    conn = cast(Connection)holder.conn;
                },
                (immutable ConnectionBusy _m)
                {
                    conn = null;
                }
            );
        }
        catch (OwnerTerminated e)
        {
            if (e.tid != thisTid) goto L_receive;
        }

        return conn;
    }

    ///
    void releaseConnection(ref Connection conn) shared
    {
        (cast(Tid)_pool).send(new shared ConnenctionHolder(cast(shared Connection)conn));
        conn = null;
    }

private:

    __gshared ConnectionPool _instance = null;

    Tid _pool;
    int _waitSeconds;
}

private:

shared bool __instantiated;

class Pool
{
    this(string host, ushort port, string user, string password, string database, string charset,
            uint maxConnections, uint initialConnections, uint incrementalConnections, Duration waitTime) shared
    {
        _host = host;
        _port = port;
        _user = user;
        _password = password;
        _database = database;
        _charset = charset;
        _maxConnections = maxConnections;
        _initialConnections = initialConnections;
        _incrementalConnections = incrementalConnections;
        _waitTime = waitTime;

        createConnections(initialConnections);
        __instantiated = true;
    }

    void opCall() shared
    {
        auto loop = true;

        while (loop)
        {
            try
            {
                receive(
                    (shared RequestConnection req)
                    {
                        getConnection(req);
                    },
                    (shared ConnenctionHolder holder)
                    {
                        releaseConnection(holder);
                    },
                    (shared Terminate t)
                    {
                        foreach (conn; _pool)
                        {
                            (cast(Connection)conn).close();
                        }

                        (cast(Tid)t.tid).send(t);
                        loop = false;
                    }
                );
            }
            catch (OwnerTerminated e) { }
        }
    }

private:

    Connection createConnection() shared
    {
        try
        {
            return new Connection(_host, _port, _user, _password, _database, _charset);
        }
        catch (Exception e)
        {
            return null;
        }
    }

    void createConnections(uint num) shared
    {
        for (int i; i < num; i++)
        {
            if ((_maxConnections > 0) && (_pool.length >= _maxConnections))
            {
                break;
            }

            Connection conn = createConnection();

            if (conn !is null)
            {
                _pool ~= cast(shared Connection)conn;
            }
        }
    }

    void getConnection(shared RequestConnection req) shared
    {
        immutable start = Clock.currTime();

        while (true)
        {
            Connection conn = getFreeConnection();

            if (conn !is null)
            {
                (cast(Tid)req.tid).send(new shared ConnenctionHolder(cast(shared Connection)conn));
                return;
            }

            if ((Clock.currTime() - start) >= _waitTime)
            {
                break;
            }
 
            Thread.sleep(100.msecs);
        }

        (cast(Tid)req.tid).send(new immutable ConnectionBusy);
    }

    Connection getFreeConnection() shared
    {
        Connection conn = findFreeConnection();

        if (conn is null)
        {
            createConnections(_incrementalConnections);
            conn = findFreeConnection();
        }     

        return conn;
    }

    Connection findFreeConnection() shared
    {
        Connection result;

        for (size_t i = 0; i < _pool.length; i++)
        {
            Connection conn = cast(Connection)_pool[i];

            if ((conn is null) || conn.busy)
            {
                continue;
            }

            if (!testConnection(conn))
            {
                conn = null;
                continue;
            }

            conn.busy = true;
            result = conn;
            break;
        }

        if (_pool.any!((a) => (a is null)))
        {
            _pool = _pool.remove!((a) => (a is null));
        }

        return result;
    }

    bool testConnection(Connection conn) shared
    {
        return (conn.ping() == 0);
    }

    void releaseConnection(shared ConnenctionHolder holder) shared
    {
        if (holder.conn !is null)
        {
            Connection conn = cast(Connection)holder.conn;
            conn.busy = false;
        }
    }

    Connection[] _pool;

    string _host;
    ushort _port;
    string _user;
    string _password;
    string _database;
    string _charset;
    uint _maxConnections;
    uint _initialConnections;
    uint _incrementalConnections;
    Duration _waitTime;
}

shared class RequestConnection
{
    Tid tid;

    this(shared Tid tid) shared
    {
        this.tid = tid;
    }
}

shared class ConnenctionHolder
{
    Connection conn;

    this(shared Connection conn) shared
    {
        this.conn = conn;
    }
}

immutable class ConnectionBusy
{
}

shared class Terminate
{
    Tid tid;

    this(shared Tid tid) shared
    {
        this.tid = tid;
    }
}

// unittest
// {
//     import core.thread;
//     import std.stdio;

//     ConnectionPool pool = ConnectionPool.getInstance("127.0.0.1", 3306, "root", "root", "mysql_d_testing", null);

//     int i = 0;
//     while (i++ < 20)
//     {
//         Thread.sleep(100.msecs);

//         Connection conn = pool.getConnection();

//         if (conn !is null)
//         {
//             writeln(conn.ping());
//             pool.releaseConnection(conn);
//         }
//     }

//     pool.destroy();
// }
