#ifndef PARTIAL_ALL_MODULE_H
#define PARTIAL_ALL_MODULE_H

void PartialAllModule_Init(int value);

static inline int PartialAllModule_DoubleValue(int value)
{
  return value * 2;
}

#endif
