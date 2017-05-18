#!/usr/bin/env python

try:
    from sonic_sfp.sfputilbase import sfputilbase
except ImportError, e:
    raise ImportError (str(e) + "- required module not found")


class sfputil(sfputilbase):
    """Platform specific sfputil class"""

    port_start = 0
    port_end = 33
    ports_in_block = 34

    eeprom_offset = 18

    port_to_eeprom_mapping = {}

    _qsfp_ports = range(0, 32 + 1)
    _sfp_ports = range(33, 34 + 1)

    def __init__(self, port_num):
        # Override port_to_eeprom_mapping for class initialization
        eeprom_path = '/sys/class/i2c-adapter/i2c-{0}/{0}-0050/eeprom'
        for x in range(0, self.port_end + 1):
            self.port_to_eeprom_mapping[x] = eeprom_path.format(x + self.eeprom_offset)
        sfputilbase.__init__(self, port_num)
