import sys
import mysql.connector

class MyDB(object):
    def __init__(self):
        config = {
            'user': 'root',
            'password': 'password',
            'host': 'localhost',
            'database': 'final_project',
            'auth_plugin': 'mysql_native_password'
        }
        try:
            self._db_conn = mysql.connector.connect(**config)
            self._db_cur = self._db_conn.cursor()
        except:
            sys.exit("Error connecting to the host. Please check your config.")
    
    def create(self):
        try:
            query = """CREATE TABLE users (
                id INT(4) AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(32) UNIQUE,
                sex CHAR(1),
                model_location VARCHAR(256),
                registration_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP)"""
            self._db_cur.execute(query)
            print("users table has been created successfully.")
        except mysql.connector.DatabaseError:
            sys.exit("An error has occured!")
    
    def fetch(self, query, params):
        self._db_cur.execute(query, params)
        return self._db_cur.fetchone()
    
    def update(self, query, params):
        self._db_cur.execute(query, params)
        self._db_conn.commit()
    
    def getLastId(self):
        return self._db_cur.lastrowid
    
    def __del__(self):
        self._db_conn.close()
