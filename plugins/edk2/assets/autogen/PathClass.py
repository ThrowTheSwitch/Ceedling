### from Misc.py in EDK2 python source
import os

class PathClass(object):
    def __init__(self, File='', Root='', AlterRoot='', Type='', IsBinary=False,
                 Arch='COMMON', ToolChainFamily='', Target='', TagName='', ToolCode=''):
        self.Arch = Arch
        self.File = str(File)
        if os.path.isabs(self.File):
            self.Root = ''
            self.AlterRoot = ''
        else:
            self.Root = str(Root)
            self.AlterRoot = str(AlterRoot)

        # Remove any '.' and '..' in path
        if self.Root:
            self.Root = mws.getWs(self.Root, self.File)
            self.Path = os.path.normpath(os.path.join(self.Root, self.File))
            self.Root = os.path.normpath(CommonPath([self.Root, self.Path]))
            # eliminate the side-effect of 'C:'
            if self.Root[-1] == ':':
                self.Root += os.path.sep
            # file path should not start with path separator
            if self.Root[-1] == os.path.sep:
                self.File = self.Path[len(self.Root):]
            else:
                self.File = self.Path[len(self.Root) + 1:]
        else:
            self.Path = os.path.normpath(self.File)

        self.SubDir, self.Name = os.path.split(self.File)
        self.BaseName, self.Ext = os.path.splitext(self.Name)

        if self.Root:
            if self.SubDir:
                self.Dir = os.path.join(self.Root, self.SubDir)
            else:
                self.Dir = self.Root
        else:
            self.Dir = self.SubDir

        if IsBinary:
            self.Type = Type
        else:
            self.Type = self.Ext.lower()

        self.IsBinary = IsBinary
        self.Target = Target
        self.TagName = TagName
        self.ToolCode = ToolCode
        self.ToolChainFamily = ToolChainFamily

        self._Key = None