#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = '''
---
module: oracle_facts
short_description: This module allows you to run get key Oracle information from the database and put it into facts
description:
    - Gets Oracle information and puts it into the Ansible facts.
version_added: "1.0"
options:
    hostName:
        description:
            - The Oracle database node
        required: false
        default: localhost
    sqlUser:
        description:
            - The Oracle user name to connect to
        required: true
    sqlPwd:
        description:
            - The Oracle user password
        required: true
    port:
        description:
            - The TNS port to connect to
        required: false
        default: 1521
    tns:
        description:
            - The TNS target to use
        required: true
 

notes:
    - Requires the installation of cx_Oracle
requirements: [ "cx_Oracle" ]
author: Tim Payne
'''

EXAMPLES = '''
# Create a new schema on Oracleserver as user scott.
- oracle_useradmin.py hostName=oracleserver.com sqlUser=scott sqlPwd=tiger tns=orcl useradmin_task=create_schema schemaName=foobar schemaPwd=humbug
# Drop a schema on Oracleserver as user scott.
- oracle_useradmin.py hostName=oracleserver.com sqlUser=scott sqlPwd=tiger tns=orcl useradmin_task=drop_schema schemaName=foobar
# Alter a schema's password.
- oracle_useradmin.py hostName=oracleserver.com sqlUser=scott sqlPwd=tiger tns=orcl useradmin_task=modify_schema schemaName=foobar schemaPwd=newpasswd

'''

import ConfigParser
import os
import warnings
import cx_Oracle
import string 
import sys
import getopt
import json

def read_params(cur,schemaName, mess,dbParams):
    sqlQ = 'SELECT name, value from V$PARAMETER' 

    try:
        cur.execute(sqlQ)
    except cx_Oracle.DatabaseError as e:
        error, = e.args
        if error.code == 942:
            mess[0] = "Error: You do not have the required privilege"
            return False
        mess[0] = sqlQ + "->" + error.message
        return False

    for name, value in cur.fetchall():
        dbParams.append(dict(name=name,value=value))
 
    return True

def read_nls_instance_params(cur,schemaName, mess,nlsInstanceParams):
    sqlQ = 'SELECT parameter, value from NLS_INSTANCE_PARAMETERS' 

    try:
        cur.execute(sqlQ)
    except cx_Oracle.DatabaseError as e:
        error, = e.args
        if error.code == 942:
            mess[0] = "Error: You do not have the required privilege"
            return False
        mess[0] = sqlQ + "->" + error.message
        return False

    for name, value in cur.fetchall():
        nlsInstanceParams.append(dict(parameter=name,value=value))
 
    return True

def read_nls_db_params(cur,schemaName, mess,nlsDbParams):
    sqlQ = 'SELECT parameter, value from NLS_DATABASE_PARAMETERS' 

    try:
        cur.execute(sqlQ)
    except cx_Oracle.DatabaseError as e:
        error, = e.args
        if error.code == 942:
            mess[0] = "Error: You do not have the required privilege"
            return False
        mess[0] = sqlQ + "->" + error.message
        return False

    for name, value in cur.fetchall():
        nlsDbParams.append(dict(parameter=name,value=value))
 
    return True

def read_dbfiles(cur,schemaName, mess,dbFiles):
    sqlQ = 'SELECT file_name, tablespace_name, bytes, status from dba_data_files' 

    try:
        cur.execute(sqlQ)
    except cx_Oracle.DatabaseError as e:
        error, = e.args
        if error.code == 942:
            mess[0] = "Error: You do not have the required privilege"
            return False
        mess[0] = sqlQ + "->" + error.message
        return False

    for file_name, tablespace_name, bytes, status in cur.fetchall():
        dbFiles.append(dict(file_name=file_name,tablespace_name=tablespace_name,bytes=bytes,status=status))
 
    return True

def read_tablespaces(cur,schemaName, mess,dbTableSpaces):
    sqlQ = 'SELECT TABLESPACE_NAME, BLOCK_SIZE, status from DBA_TABLESPACES' 

    try:
        cur.execute(sqlQ)
    except cx_Oracle.DatabaseError as e:
        error, = e.args
        if error.code == 942:
            mess[0] = "Error: You do not have the required privilege"
            return False
        mess[0] = sqlQ + "->" + error.message
        return False

    for tablespace_name, block_size, status in cur.fetchall():
        dbTableSpaces.append(dict(tablespace_name=tablespace_name,block_size=block_size,status=status))
 
    return True

def read_schemas(cur,schemaName, mess,dbSchemas):
    sqlQ = 'select username,account_status,to_char(lock_date,\'DD-MON-YYYY HH24:MI:SS\'),'
    sqlQ += 'to_char(expiry_date,\'DD-MON-YYYY HH24:MI:SS\'),'
    sqlQ += 'default_tablespace,temporary_tablespace,'
    sqlQ += 'to_char(created,\'DD-MON-YYYY HH24:MI:SS\') from dba_users'

    try:
        cur.execute(sqlQ)
    except cx_Oracle.DatabaseError as e:
        error, = e.args
        if error.code == 942:
            mess[0] = "Error: You do not have the required privilege"
            return False
        mess[0] = sqlQ + "->" + error.message
        return False

    for username, account_status, lock_date, expiry_date, default_tablespace, temporary_tablespace, created in cur.fetchall():
        dbSchemas.append(dict(username=username,account_status=account_status,
                                  lock_date=lock_date,expiry_date=expiry_date,
                                  default_tablespace=default_tablespace,
                                  temporary_tablespace=temporary_tablespace,
                                  created=created))
 
    return True

    
def main():

    mess = ['']
 
    module = AnsibleModule(
            argument_spec = dict(
            hostName=dict(default="localhost"),
            sqlUser=dict(required=True),
            sqlPwd=dict(required=True),
            port=dict(default=1521),
            tns=dict(required=True),
        )
    )

    hostName = module.params["hostName"]
    sqlUser = module.params["sqlUser"]
    sqlPwd = module.params["sqlPwd"]
    port = module.params["port"]
    tns = module.params["tns"]
   
    dsn = cx_Oracle.makedsn (hostName, port, tns)

    try:      
        # Connect to Oracle...
        con = cx_Oracle.connect (sqlUser, sqlPwd, dsn)
    except cx_Oracle.DatabaseError as e:
        error, = e.args
        mess[0] = error.message
        module.fail_json(msg=mess[0], changed=False)
        raise

    cur = con.cursor()
    dbParams = list()
    if not read_params(cur,sqlUser,mess,dbParams):
        module.fail_json(msg=mess[0], changed=False)
        raise

    nlsInstanceParams = list()
    if not read_nls_instance_params(cur,sqlUser,mess,nlsInstanceParams):
        module.fail_json(msg=mess[0], changed=False)
        raise

    nlsDbParams = list()
    if not read_nls_db_params(cur,sqlUser, mess,nlsDbParams):
        module.fail_json(msg=mess[0], changed=False)
        raise

    dbFiles = list()
    if not read_dbfiles(cur,sqlUser, mess,dbFiles):
        module.fail_json(msg=mess[0], changed=False)
        raise

    dbTableSpaces = list()
    if not read_tablespaces(cur,sqlUser, mess,dbTableSpaces):
        module.fail_json(msg=mess[0], changed=False)
        raise

    dbSchemas = list()
    if not read_schemas(cur,sqlUser, mess,dbSchemas):
        module.fail_json(msg=mess[0], changed=False)
        raise

    module.exit_json(
        ansible_facts = dict(
          dbParams = dbParams,
          nlsInstanceParams = nlsInstanceParams,
          nlsDbParams = nlsDbParams,
          dbFiles = dbFiles,
          dbTableSpaces = dbTableSpaces,
          dbSchemas = dbSchemas,
        ),
        changed = False
    )

from ansible.module_utils.basic import *
main()
