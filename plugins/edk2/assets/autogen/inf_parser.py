import configparser
from guidlib import GuidLib
import os

class inf_parser():
    def __init__(self, infpath):
        self.config = configparser.ConfigParser(strict=False, allow_no_value=True, comment_prefixes=('#','//'))
        self.config.optionxform = lambda option: option
        self.config.read(infpath)

        self.infpath = infpath
        self.guidlib = GuidLib()

        self.section_defines = 'Defines'
        self.section_sources = 'Sources'
        self.section_packages = 'Packages'
        self.section_libraryclasses = 'LibraryClasses'
        self.section_guids = 'Guids'
        self.section_protocols = 'Protocols'
        self.section_pcds = 'Pcd'
        self.section_ppis = 'Ppis'

    def parse_defines(self):
        return self.config[self.section_defines]

    def parse_sources(self):
        return self.clean_keypairs(self.config.items(self.section_sources)).keys()

    def parse_packages(self):
        return self.config[self.section_packages]

    def parse_libraryclasses(self):
        return self.config[self.section_libraryclasses]

    def parse_guids(self):
        guids = self.clean_keypairs(self.config.items(self.section_guids))
        return self.replace_guids(guids)

    def parse_protocols(self):
        protocols = self.clean_keypairs(self.config.items(self.section_protocols))
        return self.replace_guids(protocols)

    def parse_pcds(self):
        pcds = {}
        pcdSections = [pcdSection for pcdSection in self.config.sections() if 'pcd' in str(pcdSection).lower()]
        for pcdSection in pcdSections:
            pcds.update(self.clean_keypairs(self.config.items(self.section_pcds)))
        return self.replace_guids(pcds)

    def parse_ppis(self):
        ppis = self.clean_keypairs(self.config.items(self.section_ppis))
        return self.replace_guids(ppis)

    def clean_keypairs(self, items):
        cleaned_items = dict()
        for key, value in items:
            idx = key.find('#')
            clean_key = key[:(idx if idx >= 0 else len(key))].strip()
            idx = value.find('#')
            clean_value = value[:idx if idx >=0 else len(value)].strip()
            cleaned_items[clean_key] = clean_value
        return cleaned_items

    def replace_guids(self, items):
        for key, value in items.items():
            items[key] = self.guidlib.nextguid()
        return items

