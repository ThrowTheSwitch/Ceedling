## from Misc.py EDK2 tools.

## GetCharIndexOutStr
#
# Get comment character index outside a string
#
# @param Line:              The string to be checked
# @param CommentCharacter:  Comment char, used to ignore comment content
#
# @retval Index
#
def GetCharIndexOutStr(CommentCharacter, Line):
    #
    # remove whitespace
    #
    Line = Line.strip()

    #
    # Check whether comment character is in a string
    #
    InString = False
    for Index in range(0, len(Line)):
        if Line[Index] == '"':
            InString = not InString
        elif Line[Index] == CommentCharacter and InString :
            pass
        elif Line[Index] == CommentCharacter and (Index +1) < len(Line) and Line[Index+1] == CommentCharacter \
            and not InString :
            return Index
    return -1