import sys
import subprocess

from distutils.core import setup, Command

setup(name='nixops-libvirtd',
      version='@version@',
      description='NixOps backend for libvirtd',
      url='https://github.com/AmineChikhaoui/nixops-libvirtd',
      maintainer='Amine Chikhaoui',
      maintainer_email='amine.chikhaoui91@gmail.com',
      install_requires=[ "ipaddress" ],
      packages=['nixopsvirtd', 'nixopsvirtd.backends'],
      entry_points={'nixops': ['virtd = nixopsvirtd.plugin']},
      py_modules=['plugin']
)
