#include <stdio.h>

extern int foo_bar_value(void);
extern int baz_bar_value(void);

int main(void)
{
  printf("foo_bar_value=%d\n", foo_bar_value());
  printf("baz_bar_value=%d\n", baz_bar_value());
  return 0;
}
