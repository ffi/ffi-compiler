#include "example.h"

RBFFI_EXPORT long
example(void)
{
  return 0xdeadbeef;
}

RBFFI_EXPORT int 
foo(struct Example_Foo *foo)
{
  return 0;
}

RBFFI_EXPORT int 
bar(struct Example_Bar bar, struct Example_Foo *foo)
{
  return 0;
}
