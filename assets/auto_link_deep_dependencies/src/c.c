#include "c.h"
#include "never_compiled.h"

int function_from_c(int c)
{
  function_never_compiled(2);
  return 2 * c;
}
