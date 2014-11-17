#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = '''
---
module: db2_runscripts
short_description: This module allows you to run free style DB2 scripts via Ansible
description:
    - Runs free-style Postgres scripts via Ansible.
version_added: "1.0"
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
    sqlFile:
        description:
            - The name of the script file to run
        required: true
    logFile:
        description:
            - Log file in which to put output
        required: false
        default: null
 
notes:
    - Requires the installation of psycodb22
requirements: [ "ibm_db" ]
author: Tim Payne
'''

EXAMPLES = '''
# Run script /tmp/i.sql on Oracleserver as user scott.
db2_runscripts.py db2server={{db2_host}} db2port=50000 db2user=db2user db2userpwd={{db2Pwd}} db2db=test sqlFile=/tmp/i.sql
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

def main():

    inputfile = '' 
    
    mess = ''

    module = AnsibleModule(
            argument_spec = dict(
            db2server=dict(default="localhost"),
            db2port=dict(default=50000),
            db2user=dict(required=True),
            db2userpwd=dict(required=True),
            db2db=dict(required=True),
            sqlFile=dict(required=True),
            logFile=dict(default=None),
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
    inputfile = module.params["sqlFile"]
    outputfile = module.params["logFile"]
   
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

    # If an output file has been specified, then create one
    if (outputfile) and outputfile != 'STDOUT':
        ofs = open(outputfile, "w")
 
    sqlQuery = ''
    with open(inputfile, 'r') as inp:
        lineNo = 0
        for line in inp:
            lineNo = lineNo + 1
            line = line.strip()
            line = line.lstrip()
            # Skip any blank lines or SQL remark characters
            if line == '\n' or line.find('--',0,2) != -1 or line.find('REM',0,3) != -1:
                sqlQuery = ''
            elif line == '/\n' or line.find(';') != -1:
                sqlQuery = sqlQuery + line
                sqlQuery = sqlQuery.strip()
                sqlQuery = sqlQuery.strip(';')
                sqlQuery = sqlQuery.strip('/')
                sqlQuery = sqlQuery.strip('\n')
                
                if sqlQuery and not sqlQuery.isspace():
                    stmt = ibm_db.exec_immediate(con, sqlQuery)
                    if not stmt:
                        mess = "Line: "+str(lineNo)+": "+sqlQuery + "->" + ibm_db.stmt_errormsg(stmt)
                        module.fail_json(msg=mess, changed=False)
                        raise

                    if (outputfile) and outputfile != 'STDOUT':
                        ofs.write(sqlQuery+"\nCommand processed\n")
                    elif (outputfile) and outputfile == 'STDOUT':
                        mess = mess + sqlQuery+"\nCommand processed\n"

                sqlQuery = ''

            else:
                sqlQuery = sqlQuery + line
    
    if (outputfile) and outputfile != 'STDOUT':
        ofs.close()
    inp.close()
    ibm_db.close(con)

    if not outputfile:
        mess = "SQL file processed"

    module.exit_json(msg=mess, changed=True)

from ansible.module_utils.basic import *
main()
