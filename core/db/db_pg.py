from core import ibs_exceptions
from core.db.ibs_db import *
import pg
import time

try:
    from pg import error as PGError
except ImportError:
    from pg import Error as PGError

class db_pg (ibs_db):
    
    def connect(self,dbname,host,port,user,password):
        """
        Connect to PostgreSQL database.
        Supports both local (Unix socket) and external (TCP/IP) connections.
        
        Args:
            dbname: Database name
            host: None for Unix socket, or hostname/IP for TCP/IP connection
            port: Port number (ignored for Unix socket connections)
            user: Database username
            password: Database password
        """
        try:
            # For external connections (host is not None), ensure we use TCP/IP
            # For local connections (host is None), use Unix socket
            if host is None or host == "":
                # Local connection via Unix socket
                self.connHandle=pg.connect(dbname,None,None,None,None,user,password)
            else:
                # External connection via TCP/IP
                # Convert port to integer if it's a string
                try:
                    port = int(port)
                except (ValueError, TypeError):
                    port = 5432  # Default PostgreSQL port
                self.connHandle=pg.connect(dbname,host,port,None,None,user,password)
        except PGError,e:
            # Provide more informative error messages for external connections
            if host is not None and host != "":
                error_msg = "Failed to connect to external PostgreSQL database at %s:%s - %s" % (host, port, str(e))
            else:
                error_msg = "Failed to connect to local PostgreSQL database - %s" % str(e)
            raise ibs_exceptions.DBException(error_msg)
        except Exception,e:
            # Handle other exceptions (network errors, etc.)
            if host is not None and host != "":
                error_msg = "Network error connecting to external PostgreSQL at %s:%s - %s" % (host, port, str(e))
            else:
                error_msg = "Error connecting to PostgreSQL - %s" % str(e)
            raise ibs_exceptions.DBException(error_msg)

    def prepareQuery(self,plan_name, args , query):
        self._runQuery("prepare %s (%s) as %s"%(plan_name,",".join(args),query))

    def executePrepared(self, plan_name, values):
        return self.selectQuery("execute %s (%s)"%(plan_name,",".join(map(str,values))))

    def _runQueryDB(self,query):
        """
            run the query , no exception handling done here
            return result set of query
        """
        connection=self.getConnection()
        return connection.query(query)
        
    def transactionQuery(self,query):
        ibs_db.transactionQuery(self,query)
        query_len=len(query)
        if query_len>4000:
            self.__transactionQuery("BEGIN;")
            sent=0
            while sent<query_len:
                end=(sent+4000,query_len)[sent+4000>query_len]
                while query[end-1]!=";": end+=1
                self.__transactionQuery(query[sent:end])
                sent=end
            self.__transactionQuery("COMMIT;")
        else:
            return self.__transactionQuery("BEGIN; %s COMMIT;"%query)
    
    def __transactionQuery(self,command):
        try:
            return self._runQuery(command)
        except PGError,e:
            try:
                self._runQuery("ABORT;")
            except:
                pass
        
            raise ibs_exceptions.DBException("%s query: %s" %(e,command))

        except Exception,e:
            try:
                self._runQuery("ABORT;")
            except:
                pass
            logException(LOG_ERROR)

            raise ibs_exceptions.DBException("%s query: %s" %(e,command))

    def query(self,command):
        try:
            return self._runQuery(command)
        except PGError,e:
            raise ibs_exceptions.DBException("%s query: %s" %(e,command))

        except Exception,e:
            raise ibs_exceptions.DBException("%s query: %s" %(e,command))

    def runIBSQuery(self,ibs_query):
        self.__transactionQuery("BEGIN;")
        map(self.__transactionQuery,ibs_query)
        self.__transactionQuery("COMMIT;")
    
    def check(self):
        try:
            self.query("BEGIN;ROLLBACK;")
        except Exception,e:
            try:
                self.reset()
            except Exception,e:
                raise ibs_exceptions.DBException("check function on reseting connection %s"%e)
            except PGError,e:
                raise ibs_exceptions.DBException("check function on reseting connection %s"%e)
    