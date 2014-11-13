#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = '''
---
module: oracle_useradmin
short_description: This module allows you to run perform Oracle user admin tasks via Ansible
description:
    - Runs Oracle user admin commands via Ansible.
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
    useradmin_task:
        description:
            - The name of the user admin task to perform
        required: true
    default_tablespace:
        description:
            - The name of the default tablespace for a new schema
        required: false
        default: null
    temporary_tablespace:
        description:
            - The name of the temporary tablespace for a new schema
        required: false
        default: null  
    schemaRoles:
        description:
            - The roles that will be granted to a new schema
        required: false
        default: null
    schemaName:
        description:
            - The schema that will be affected
        required: false
        default: null
    schemaPwd:
        description:
            - The password for the affected schema
        required: false
        default: null

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

def check_priv(cur,schemaName, mess):
   sqlQ = 'SELECT COUNT(*) FROM sys.dba_role_privs WHERE granted_role = \'DBA\'' 
   sqlQ += ' AND upper(grantee) = upper(\''+schemaName+'\')'

   try:
        cur.execute(sqlQ)
   except cx_Oracle.DatabaseError as e:
        error, = e.args
        if error.code == 942:
            mess[0] = "Error: You do not have the required DBA privilege"
            return False
        mess[0] = sqlQ + "->" + error.message
        return False

   count = cur.fetchall()[0][0]
   if count > 0: 
       return True

   return False

def create_schema(cur,schemaName,schemaPwd,default_tablespace,temporary_tablespace,schemaRoles,mess):
    sqlQ = 'CREATE USER '+schemaName+' IDENTIFIED BY '+schemaPwd+' '
    if (default_tablespace): 
        sqlQ += 'DEFAULT TABLESPACE '+default_tablespace+' '
    if (temporary_tablespace):
        sqlQ += 'TEMPORARY TABLESPACE '+temporary_tablespace+' '
    if (default_tablespace):
        sqlQ += 'QUOTA UNLIMITED ON '+default_tablespace

    try:
        cur.execute(sqlQ)
    except cx_Oracle.DatabaseError as e:
        error, = e.args
        mess[0] = sqlQ + "->" + error.message
        return False

    if (schemaRoles):
        sqlQ = 'GRANT '+schemaRoles+' TO '+schemaName
    else:
        sqlQ = 'GRANT CONNECT, RESOURCE TO '+schemaName

    try:
        cur.execute(sqlQ)
    except cx_Oracle.DatabaseError as e:
        error, = e.args
        mess[0] = sqlQ + "->" + error.message
        return False

    return True

def drop_schema(cur,schemaName,schemaPwd,mess):
    sqlQ = 'DROP USER '+schemaName+' CASCADE'

    try:
        cur.execute(sqlQ)
    except cx_Oracle.DatabaseError as e:
        error, = e.args
        if error.code == 1918:
            mess[0] = "Error: The schema specified does not exist"
            return False
        mess[0] = sqlQ + "->" + error.message
        return False

    return True

def alter_schema(cur,schemaName,schemaPwd,mess):
    sqlQ = 'ALTER USER '+schemaName+' IDENTIFIED BY '+schemaPwd

    try:
        cur.execute(sqlQ)
    except cx_Oracle.DatabaseError as e:
        error, = e.args
        if error.code == 1918:
            mess[0] = "Error: The schema specified does not exist"
            return False
        mess[0] = sqlQ + "->" + error.message
        return False

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
            useradmin_task=dict(default="noop",choices=["create_schema", "drop_schema", "modify_schema"]),
            default_tablespace=dict(default=None),
            temporary_tablespace=dict(default=None),
            schemaRoles=dict(default=None),
            schemaName=dict(default=None),
            schemaPwd=dict(default=None),            
        )
    )

    hostName = module.params["hostName"]
    sqlUser = module.params["sqlUser"]
    sqlPwd = module.params["sqlPwd"]
    port = module.params["port"]
    tns = module.params["tns"]
   
    dsn = cx_Oracle.makedsn (hostName, port, tns)

    useradmin_task = module.params["useradmin_task"]
    default_tablespace = module.params["default_tablespace"]
    temporary_tablespace = module.params["temporary_tablespace"]
    schemaRoles = module.params["schemaRoles"]
    schemaName = module.params["schemaName"]
    schemaPwd = module.params["schemaPwd"]

    try:      
        # Connect to Oracle...
        con = cx_Oracle.connect (sqlUser, sqlPwd, dsn)
    except cx_Oracle.DatabaseError as e:
        error, = e.args
        mess[0] = error.message
        module.fail_json(msg=mess[0], changed=False)
        raise

    cur = con.cursor()
    if not check_priv(cur,sqlUser,mess):
        module.fail_json(msg=mess[0], changed=False)
        raise

    if useradmin_task == "create_schema":
        if create_schema(cur,schemaName,schemaPwd,default_tablespace,temporary_tablespace,schemaRoles,mess):
            mess[0] = 'The schema has been successfully created'
        else:
            module.fail_json(msg=mess[0], changed=False)
            raise
    elif useradmin_task == "drop_schema":
        if drop_schema(cur,schemaName,schemaPwd,mess):
            mess[0] = 'The schema has been successfully dropped'
        else:
            module.fail_json(msg=mess[0], changed=False)
            raise
    elif useradmin_task == "modify_schema":
        if alter_schema(cur,schemaName,schemaPwd,mess):
            mess[0] = 'The schema has been successfully modified'
        else:
            module.fail_json(msg=mess[0], changed=False)
            raise
    else:
        module.fail_json(msg="The option you have specified is not supported", changed=False)
        raise

    module.exit_json(msg=mess[0], changed=True)

from ansible.module_utils.basic import *
main()
