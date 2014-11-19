#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = '''
---
module: oracle_facts
short_description: This module allows you to import an Oracle database using the PL/SQL interface for data pump
description:
    - Restores an Oracle database from existing export files.
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
    mode:
        description:
            - The EXPORT mode to use
        required: false
        default: FULL
    directory:
        description:
            - The directory to use for data pump. This MUST be a valid Oracle directory object
        required: false
        default: DATA_PUMP_DIR
    filename:
        description:
            - The export filename pattern to use.
        required: false
        default: EXPDAT%U.DMP

notes:
    - Requires the installation of cx_Oracle
requirements: [ "cx_Oracle" ]
author: Tim Payne
'''

EXAMPLES = '''
# Get the facts
oracle_backup.py hostName={{oracle_host}} sqlUser=system sqlPwd=manager port=1521 tns=dim12 
'''

import ConfigParser
import os
import warnings
import cx_Oracle
import string 
import sys
import getopt
import json
from time import gmtime, strftime


# Run the PL/SQL...
def runDataDump(cur,schemaName,mess,mode,directory,filename):

    importLog = 'IMPORT'+strftime("%Y%m%d%H%M%S", gmtime())+'.LOG' 

    sqlQ =  'BEGIN declare\n'
    sqlQ += '   h1   NUMBER;\n'
    sqlQ += 'begin\n'
    sqlQ += '  h1 := dbms_datapump.open (operation => \'IMPORT\', job_mode => \''+mode+'\', version => \'COMPATIBLE\');\n' 
    sqlQ += '  dbms_datapump.set_parallel(handle => h1, degree => 1);\n' 
    sqlQ += '  dbms_datapump.add_file(handle => h1, filename => \''+importLog+'\', directory => \''+directory+'\', filetype => 3);\n' 
    sqlQ += '  dbms_datapump.set_parameter(handle => h1, name => \'KEEP_MASTER\', value => 0);\n' 
    sqlQ += '  dbms_datapump.add_file(handle => h1, filename => \''+filename[0]+'\', directory => \''+directory+'\', filetype => 1);\n' 
    sqlQ += '  dbms_datapump.set_parameter(handle => h1, name => \'INCLUDE_METADATA\', value => 1);\n' 
    sqlQ += '  dbms_datapump.set_parameter(handle => h1, name => \'DATA_ACCESS_METHOD\', value => \'AUTOMATIC\');\n' 
    sqlQ += '  dbms_datapump.set_parameter(handle => h1, name => \'REUSE_DATAFILES\', value => 0);\n' 
    sqlQ += '  dbms_datapump.set_parameter(handle => h1, name => \'SKIP_UNUSABLE_INDEXES\', value => 0);\n' 
    sqlQ += '  dbms_datapump.start_job(handle => h1, skip_current => 0, abort_step => 0);\n' 
    sqlQ += '  dbms_datapump.detach(handle => h1);\n' 
    sqlQ += 'end; END;'
 
    try:
        cur.execute(sqlQ)
    except cx_Oracle.DatabaseError as e:
        error, = e.args
        if error.code == 942:
            mess[0] = "Error: You do not have the required privilege"
            return False
        mess[0] = sqlQ + "->" + error.message
        return False

    mess[0] = "The restore job has been started with the filename "+filename[0]

    filename.append(importLog)
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
            mode=dict(default="FULL"),
            directory=dict(default="DATA_PUMP_DIR"),
            filename=dict(default="EXPDAT%U.DMP")
        )
    )

    hostName = module.params["hostName"]
    sqlUser = module.params["sqlUser"]
    sqlPwd = module.params["sqlPwd"]
    port = module.params["port"]
    tns = module.params["tns"]
    mode = module.params["mode"]
    directory = module.params["directory"]
    filename = module.params["filename"]

    dsn = cx_Oracle.makedsn (hostName, port, tns)

    try:      
        # Connect to Oracle...
        con = cx_Oracle.connect (sqlUser, sqlPwd, dsn)
    except cx_Oracle.DatabaseError as e:
        error, = e.args
        mess[0] = error.message
        module.fail_json(msg=mess[0], changed=False)
        raise

    file_list = list()
    file_list.append(filename)
    cur = con.cursor()
    if not runDataDump(cur,sqlUser,mess,mode,directory,file_list):
        module.fail_json(msg=mess[0], changed=False)
        raise

    module.exit_json(
        msg=mess[0],
        ansible_facts = dict(import_logfile=file_list[1]),
        changed = True
    )

from ansible.module_utils.basic import *
main()
