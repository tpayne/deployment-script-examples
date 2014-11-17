#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = '''
---
module: db2_facts
short_description: This module allows you to run get key DB2 information from the database and put it into facts
description:
    - Gets DB2 information and puts it into the Ansible facts.
version_added: "1.0"
options:
 options:
     db2server:
        description:
            - The DB2 database server
        required: false
        default: localhost
    db2port:
        description:
            - The DB2 port to connect to
        required: false
        default: 50000
    db2user:
        description:
            - The DB2 user to connect to
        required: true
    db2userpwd:
        description:
            - The password of the user
        required: true
    db2db:
        description:
            - The DB2 database to connect to
        required: true
notes:
    - Requires the installation of ibm_db
requirements: [ "ibm_db" ]
author: Tim Payne
'''

EXAMPLES = '''
# Get the facts
db2_facts.py db2server="{{db2_host}}" db2port=50000 db2user=db2cntl db2userpwd="{{db2Pwd}}" db2db="{{dbName}}"
'''

import ConfigParser
import os
import warnings
import string 
import sys
import getopt
import json

try:
    import ibm_db
except ImportError:
    db2py_installed = False
else:
    db2py_installed = True

# Read the Database parameters...
def read_dbparams(con, mess,dbParams):
    sqlQ = 'select name,value from SYSIBMADM.DBCFG' 

    stmt = ibm_db.exec_immediate(con, sqlQ)
    if not stmt:
        mess[0] = sqlQ + "->" + ibm_db.stmt_errormsg(stmt)
        module.fail_json(msg=mess, changed=False)
        raise

    dictionary = ibm_db.fetch_assoc(stmt)
    while dictionary != False:
        name = dictionary["NAME"]
        value = dictionary["VALUE"]
        dbParams.append(dict(name=name,value=value))   
        dictionary = ibm_db.fetch_assoc(stmt)  
        
    return True

# Read the Database parameters...
def read_dbInsparams(con, mess,dbInsParams):
    sqlQ = 'select name,value from SYSIBMADM.DBMCFG' 

    stmt = ibm_db.exec_immediate(con, sqlQ)
    if not stmt:
        mess[0] = sqlQ + "->" + ibm_db.stmt_errormsg(stmt)
        module.fail_json(msg=mess, changed=False)
        raise

    dictionary = ibm_db.fetch_assoc(stmt)
    while dictionary != False:
        name = dictionary["NAME"]
        value = dictionary["VALUE"]
        dbInsParams.append(dict(name=name,value=value))   
        dictionary = ibm_db.fetch_assoc(stmt)  
        
    return True

# Read the Database tablespaces...
def read_tablespaces(con, mess,dbTableSpaces):
    sqlQ = 'select TABLESPACE_NAME,BLOCK_SIZE,STATUS,CONTENTS,SEGMENT_SPACE_MANAGEMENT from SYSIBMADM.DBA_TABLESPACES' 

    stmt = ibm_db.exec_immediate(con, sqlQ)
    if not stmt:
        mess[0] = sqlQ + "->" + ibm_db.stmt_errormsg(stmt)
        module.fail_json(msg=mess, changed=False)
        raise

    dictionary = ibm_db.fetch_assoc(stmt)
    while dictionary != False:
        tablespace_name = dictionary["TABLESPACE_NAME"]
        block_size = dictionary["BLOCK_SIZE"]
        status = dictionary["STATUS"]
        contents = dictionary["CONTENTS"]
        segment_management = dictionary["SEGMENT_SPACE_MANAGEMENT"]
        dbTableSpaces.append(dict(tablespace_name=tablespace_name,
                                  block_size=block_size,
                                  status=status,
                                  contents=contents,
                                  segment_management=segment_management))   
        dictionary = ibm_db.fetch_assoc(stmt)  
        
    return True

def read_schemas(con,mess,dbSchemas):
    sqlQ = 'select SCHEMANAME,owner,cast(CREATE_TIME AS VARCHAR(35)) from syscat.SCHEMATA' 

    stmt = ibm_db.exec_immediate(con, sqlQ)
    if not stmt:
        mess[0] = sqlQ + "->" + ibm_db.stmt_errormsg(stmt)
        module.fail_json(msg=mess, changed=False)
        raise

    dictionary = ibm_db.fetch_assoc(stmt)
    while dictionary != False:
        schema_name = dictionary["SCHEMANAME"]
        owner = dictionary["OWNER"]
        create_time = dictionary["3"]
        dbSchemas.append(dict(schema_name=schema_name,
                              owner=owner,
                              create_time=create_time))   
        dictionary = ibm_db.fetch_assoc(stmt)  
        
    return True

def main():

    mess = ['']

    module = AnsibleModule(
            argument_spec = dict(
            db2server=dict(default="localhost"),
            db2port=dict(default=50000),
            db2user=dict(required=True),
            db2userpwd=dict(required=True),
            db2db=dict(required=True)
       )
    )

    if not db2py_installed:
        module.fail_json(msg="IBM_DB has not been located", changed=False)    
        raise

    db2server = module.params["db2server"]
    db2port = module.params["db2port"]
    db2user = module.params["db2user"]
    db2userpwd = module.params["db2userpwd"]
    db2db = module.params["db2db"]
   
    conStr = "DATABASE="+db2db+";"
    conStr += "HOSTNAME="+db2server+";"
    conStr += "PORT="+db2port+";"
    conStr += "PROTOCOL=TCPIP;"
    conStr += "UID="+db2user+";"
    conStr += "PWD="+db2userpwd

    con = ibm_db.connect (conStr,"","")
    if not con:
        mess[0] = ibm_db.conn_errormsg()
        module.fail_json(msg=mess[0], changed=False)
        raise

    dbParams = list()
    if not read_dbparams(con,mess,dbParams):
        module.fail_json(msg=mess[0], changed=False)
        raise

    dbInsParams = list()
    if not read_dbInsparams(con, mess,dbInsParams):
        module.fail_json(msg=mess[0], changed=False)
        raise

    dbTableSpaces = list()
    if not read_tablespaces(con, mess,dbTableSpaces):
        module.fail_json(msg=mess[0], changed=False)
        raise

    dbSchemas = list()
    if not read_schemas(con,mess,dbSchemas):
        module.fail_json(msg=mess[0], changed=False)
        raise

    module.exit_json(
        ansible_facts = dict(
          dbParams = dbParams,
          dbInsParams = dbInsParams,
          dbTableSpaces = dbTableSpaces,
          dbSchemas = dbSchemas
        ),
        changed = False
    )

from ansible.module_utils.basic import *
main()
