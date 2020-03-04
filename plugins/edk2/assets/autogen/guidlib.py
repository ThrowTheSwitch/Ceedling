# © Copyright 2019-2020 HP Development Company, L.P.
# SPDX-License-Identifier: MIT

from uuid import UUID

class GuidLib():

    class __impl:
        def __init__(self):
            self.guid = UUID('00000000-0000-0000-0000-000000000000')

    __instance = None

    def __init__(self):
        if GuidLib.__instance is None:
            GuidLib.__instance = GuidLib.__impl()


    def nextguid(self):
        curr = self.__instance.guid
        nextguid = curr.int + 1
        self.__instance.guid = UUID(int=nextguid)
        return self.reformat_guid(curr)

    def reformat_guid(self, guid):
        # can be made better using UUID
        guid = str(guid).strip().replace('-', '')
        formated_guid = "{0x" + "{0}, 0x{1}, 0x{2}".format(guid[:8], guid[8:12], guid[12:16]) + ", {" + "0x{0}".format(guid[16:18])

        for i in range(18, len(guid), 2):
            formated_guid = formated_guid + ', 0x{0}'.format(guid[i:i+2])

        return formated_guid + "}}"

