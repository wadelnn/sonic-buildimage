#! /usr/bin/python

try:
   from sonic_sfp.sfputilbase import sfputilbase
except ImportError, e:
    raise ImportError (str(e) + "- required module not found")


class sfputil(sfputilbase):
    """Platform specific sfputil class"""

    port_start = 0
    port_end = 31
    ports_in_block = 32


    port_to_eeprom_mapping = {}
    _qsfp_ports = range(0, ports_in_block + 1)
   
    def __init__(self, port_num):
        # Override port_to_eeprom_mapping for class initialization
        eeprom_path = '/sys/bus/i2c/devices/{0}-0050/sfp_eeprom'
        for x in range(self.port_start, self.port_end + 1):
            self.port_to_eeprom_mapping[x] = eeprom_path.format(x + 18)
        sfputilbase.__init__(self, port_num)
