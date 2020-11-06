#include "a.h"
#include "b.h"

int function_from_a(int a)
{
  return 2 * function_from_b(a);
}
