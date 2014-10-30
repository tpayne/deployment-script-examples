#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = '''
---
module: exterminate
short_description: Invoking this module will exterminate you
# Exterminate... Exterminate...
# Exterminate... Exterminate...
# Exterminate... Exterminate...
# Exterminate... Exterminate...
# Exterminate... Exterminate...
# Exterminate... Exterminate...
# Exterminate... Exterminate...
'''

import ConfigParser
import os
import warnings

def main():
    module = AnsibleModule(
            argument_spec = dict(
            darlek=dict(default=None),
            exterminate_mode=dict(default="bydarlek", choices=["bydarlek", "bycyberman", "bychainsaw"]),
        )
    )

    creature = module.params["darlek"]
    mode = module.params["exterminate_mode"]
    messE=[]
    if mode in "bydarlek":
    	messE.append("killed by a Darlek")
    elif mode in "bycyberman":
    	messE.append("killed by a Cyberman")
    else:
    	messE.append("killed by an insane chainsaw")

    mess=[]
    mess.append("You have been exterminated " + ''.join(messE))
    mess.append(" via " + creature)

    if mode in "bychainsaw":
    	module.exit_json(msg=mess, changed=False)
    else:
 	  	module.exit_json(msg=mess, changed=True)
 
from ansible.module_utils.basic import *
main()
