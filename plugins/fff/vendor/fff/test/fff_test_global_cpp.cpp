/* =========================================================================
    Vendored third-party source, under its own copyright and license.
    Not Ceedling code, and carries no Ceedling copyright banner.

    Fake Function Framework ⏩️ https://github.com/meekrosoft/fff
    License ⏩️ plugins/fff/vendor/fff/LICENSE
========================================================================= */



extern "C"{
    #include "global_fakes.h"
}
#include <gtest/gtest.h>

DEFINE_FFF_GLOBALS;

class FFFTestSuite: public testing::Test
{
public:
    void SetUp()
    {
        RESET_FAKE(voidfunc1);
        RESET_FAKE(voidfunc2);
        RESET_FAKE(longfunc0);
        FFF_RESET_HISTORY();
    }
};

#include "test_cases.include"


