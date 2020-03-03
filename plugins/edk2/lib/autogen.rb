# © Copyright 2019-2020 HP Development Company, L.P.
# SPDX-License-Identifier: MIT

class AutoGen
    def module_autogen(autogen_tool_path, inf_path, destination)
        cmd = "py -3 #{autogen_tool_path} #{inf_path} #{destination}"
        status = system(cmd)
        if !status
            puts "Autogen: [#{cmd}]: failed."
            raise
        end
    end
end