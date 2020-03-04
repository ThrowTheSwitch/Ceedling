// © Copyright 2019-2020 HP Development Company, L.P.
// SPDX-License-Identifier: MIT

#include <stdlib.h>
#include <string.h>
#include "mock_BaseMemoryLib.h"

void * callback_ZeroMem(void *Buffer, UINTN Length, int cmock_num_calls) {
    return memset(Buffer, 0, Length);
}

void RegisterBaseMemoryLibStubs() {
    ZeroMem_StubWithCallback(callback_ZeroMem);
}

void UnregisterBaseMemoryLibStubs() {
    mock_BaseMemoryLib_Destroy();
}