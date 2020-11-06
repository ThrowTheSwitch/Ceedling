#include "b.h"
#include "c.h"

int function_from_b(int b)
{
  return 2 * function_from_c(b);
}
