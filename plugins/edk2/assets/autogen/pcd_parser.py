# © Copyright 2019-2020 HP Development Company, L.P.
# SPDX-License-Identifier: MIT

import os
import re
import pathlib
from guidlib import GuidLib

TAB_PCDS = 'Pcds'
TAB_PCDS_FIXED_AT_BUILD = 'FixedAtBuild'
TAB_PCDS_PATCHABLE_IN_MODULE = 'PatchableInModule'
TAB_PCDS_FEATURE_FLAG = 'FeatureFlag'
TAB_PCDS_DYNAMIC_EX = 'DynamicEx'
TAB_PCDS_DYNAMIC_EX_DEFAULT = 'DynamicExDefault'
TAB_PCDS_DYNAMIC_EX_VPD = 'DynamicExVpd'
TAB_PCDS_DYNAMIC_EX_HII = 'DynamicExHii'
TAB_PCDS_DYNAMIC = 'Dynamic'
TAB_PCDS_DYNAMIC_DEFAULT = 'DynamicDefault'
TAB_PCDS_DYNAMIC_VPD = 'DynamicVpd'
TAB_PCDS_DYNAMIC_HII = 'DynamicHii'

DatumSizeStringDatabase = {'8':'UINT8','16':'UINT16','32':'UINT32','64':'UINT64','Bool':'BOOLEAN','Ptr':'VOID*'}
DatumDefaultValueDatabase = {'UINT8':8,'UINT16':16,'UINT32':32,'UINT64':64,'BOOLEAN':'FALSE','VOID*':'{ 0xdc, 0x5b, 0xc2, 0xee, 0xf2, 0x67, 0x95, 0x4d, 0xb1, 0xd5, 0xf8, 0x1b, 0x20, 0x39, 0xd1, 0x1d }'}

class pcd_token_tracker():

    class __impl:
        def __init__(self):
            self.TokenValue = 0

    __instance = None

    def __init__(self):
        if pcd_token_tracker.__instance is None:
            pcd_token_tracker.__instance = pcd_token_tracker.__impl()

    def curr_pcd_token(self):
        return self.__instance.TokenValue

    def next_pcd_token(self):
        curr = self.__instance.TokenValue
        self.__instance.TokenValue += 1
        return curr

    def token_not_in_use(self, valueToCheck):
        if valueToCheck is None or valueToCheck >= self.__instance:
            return False
        return True

    def token_already_in_use(self, valueToCheck):
        if valueToCheck is None or valueToCheck < self.__instance:
            return False
        return True

class pcd():

    def __init__(self, rawPcd):
        # split pcds into TokenSpaceGuidCName.TokenCName|DefaultValue|DatumType|TokenValue
        (pcdTokenSpaceGuidCName, pcdTokenCName, pcdDefaultValue, pcdDatumType, pcdTokenValue) = pcd.split_raw_pcd(rawPcd)

        self.Type = None
        self.TokenSpaceGuidCName = pcdTokenSpaceGuidCName
        self.TokenCName = pcdTokenCName
        self.DefaultValue = pcdDefaultValue
        self.DatumType = pcdDatumType
        self.TokenValue = pcdTokenValue
        self.TokenSpaceGuidValue = None
        self.MaxDatumSize = 32 # default?

    @ staticmethod
    def split_raw_pcd(rawPcd):
        rawPcd = rawPcd.strip()
        split = rawPcd.split('.')
        pcdTokenSpaceGuidCName = split[0]

        split = split[1].split('|')
        pcdTokenCName = split[0]

        # skipping these items since they normally don't get put into infs anyway, just let the pcd_parser
        # populate these values
        # pcdValue = split[1]
        # pcdDatumType = split[2]
        # pcd
        return (pcdTokenSpaceGuidCName, pcdTokenCName, None, None, None)

class pcd_parser():

    @staticmethod
    def process_pcds(sourceFiles, pcds):
        ambiguousDatumTypePcds = []
        tracker = pcd_token_tracker()
        guidlib = GuidLib()

        # find the pcds we need to 'fix'
        for pcd in pcds:
            # first override TokenValue to a unit test administered value
            pcd.TokenValue = str(tracker.next_pcd_token())
            # override TokenSpaceGuidValue to a unit test administered value
            pcd.TokenSpaceGuidValue = guidlib.nextguid()
            # just assume dynamic for unit tests so that the value is not extern
            pcd.Type = TAB_PCDS_DYNAMIC
            if pcd.DatumType is None:
                ambiguousDatumTypePcds.append(pcd)

        # before processing open the .c files and get the contents
        cFileContents = {}
        for sourceFile in sourceFiles:
            if sourceFile.Ext == '.c':
                try:
                    file = open(sourceFile.Path,'r')
                    contents = file.read()
                    cFileContents[sourceFile.Name] = contents
                except:
                    raise FileNotFoundError("Could not file {0}, possibly does not exist?".format(sourceFile.Path))

        # determine the pcd datum type
        for pcd in ambiguousDatumTypePcds:
            # search each of the source files for references to pcd
            getPcdMatches = []
            setPcdMatches = []
            match = False
            for key in cFileContents:
                fileContents = cFileContents[key]

                if pcd.TokenCName not in fileContents:
                    continue

                match = True
                getPattern = r'PcdGet(.*?)\({0}\)'.format(pcd.TokenCName)
                getMatch = re.search(getPattern, fileContents)
                if getMatch is not None:
                    getPcdMatches.append(getMatch.group())

                setPattern = r'PcdSet(.*?)\({0},'.format(pcd.TokenCName)
                setMatch = re.search(setPattern, fileContents)
                if setMatch is not None:
                    setPcdMatches.append(setMatch.group())

            # raise if pcd wasn't found, can't continue from here need to look at dec files?
            if match is False or (len(getPcdMatches) == 0 and len(setPcdMatches) == 0):
                raise NotImplementedError("PCD: {0} was not referenced in any source file, could not infer datum type.".format(pcd.TokenCName))

            if len(setPcdMatches) > 0:
                # need to get the pcd datum type
                datumType = setPcdMatches[0].strip().replace(' ', '').split('(')[0].replace('PcdSet','')
                datumType = datumType.replace('S','')
            elif len(getPcdMatches) > 0:
                # need to get the pcd datum type
                datumType = getPcdMatches[0].strip().replace(' ', '').split('(')[0].replace('PcdGet','')
                datumType = datumType.replace('S','')
            else:
                raise NotImplementedError("Not sure how we would have gotten here. Raising exception.")

            # given the datum type assign a default value
            try:
                pcd.DatumType = DatumSizeStringDatabase[datumType]
            except KeyError:
                raise KeyError("In PcdGet or PcdSet a data type {0} was referenced. This type is not supported in EDK2.".format(datumType))

            # assign a default value just to get tests to run, tests should not rely on this default value and instead force returns from PcdGet
            pcd.DefaultValue = DatumDefaultValueDatabase[pcd.DatumType]
