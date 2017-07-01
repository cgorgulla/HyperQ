"""
Setup script for HyperQ

You can install lomap with

python setup.py install
"""

import sys,os
from os.path import relpath, join

from setuptools import setup, find_packages

if sys.argv[-1] == 'setup.py':
    print("To install, run 'python setup.py install'")
    print()

if sys.version_info[:2] < (2, 7):
    print("HyperQ requires Python 2.7 or later")
    sys.exit(-1)


descr = """
HyperQ
"""

setup(
    name                 = 'hyperq', 
    version              = '0.0.1', 
    description          = 'HyperQ',
    long_description     = descr,
    license              = 'LGPL',
    platforms            = ['Linux-64', 'Mac OSX-64', 'Unix-64'],
    packages             = find_packages()+['hyperq'],
    include_package_data = True,      
    zip_safe             = False
)

