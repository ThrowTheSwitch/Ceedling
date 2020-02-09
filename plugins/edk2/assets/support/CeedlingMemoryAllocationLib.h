#include <stdlib.h>
#include <string.h>
#include <Base.h>
#include "mock_MemoryAllocationLib.h"

UINTN PageSize = SIZE_4KB;

void* callback_AllocatePages(UINTN Pages, int cmock_num_calls) {
    return Pages > 0 ? malloc(Pages * PageSize) : NULL;
}

// not validated not used in HpCore
void* callback_AllocateRuntimePages(UINTN Pages, int cmock_num_calls) {
    return callback_AllocatePages(Pages, cmock_num_calls);
}

// not validated
void* callback_AllocateReservedPages(UINTN Pages, int cmock_num_calls) {
    return callback_AllocatePages(Pages, cmock_num_calls);
}
// not validated
void callback_FreePages(void *Buffer, UINTN Pages, int cmock_num_calls) {
    free(Buffer);
}
// not validated
void* callback_AllocateAlignedPages(UINTN Pages, UINTN Alignment, int cmock_num_calls) {
    return callback_AllocatePages(Pages, cmock_num_calls);
}
// not validated
void* callback_AllocateAlignedRuntimePages(UINTN Pages, UINTN Alignment, int cmock_num_calls) {
    return callback_AllocatePages(Pages, cmock_num_calls);
}
// not validated
void* callback_AllocateAlignedReservedPages(UINTN Pages, UINTN Alignment, int cmock_num_calls) {
    return callback_AllocatePages(Pages, cmock_num_calls);
}
// not validated
void callback_FreeAlignedPages(void *Buffer, UINTN Pages, int cmock_num_calls) {
    free(Buffer);
}
// not validated
void* callback_AllocatePool(UINTN AllocationSize, int cmock_num_calls) {
    return AllocationSize >= 0 ? (void*) malloc(AllocationSize) : NULL;
}
// not validated
void* callback_AllocateRuntimePool(UINTN AllocationSize, int cmock_num_calls) {
    return callback_AllocatePool(AllocationSize, cmock_num_calls);
}
// not validated
void* callback_AllocateReservedPool(UINTN AllocationSize, int cmock_num_calls) {
    return callback_AllocatePool(AllocationSize, cmock_num_calls);
}

void* callback_AllocateZeroPool(UINTN AllocationSize, int cmock_num_calls) {
    return AllocationSize >= 0 ? (void*) calloc(AllocationSize, 1) : NULL;
}
// not validated
void* callback_AllocateRuntimeZeroPool(UINTN AllocationSize, int cmock_num_calls) {
    return callback_AllocateZeroPool(AllocationSize, cmock_num_calls);
}
// not validated
void* callback_AllocateReservedZeroPool(UINTN AllocationSize, int cmock_num_calls) {
    return callback_AllocateZeroPool(AllocationSize, cmock_num_calls);
}
// not validated
void* callback_AllocateCopyPool(UINTN AllocationSize, const void *Buffer, int cmock_num_calls) {
    if (Buffer == NULL || AllocationSize > MAX_ADDRESS - sizeof(Buffer) + 1) {
        exit(-1);
    }
    void *NewBuffer = calloc(AllocationSize, 1);
    memcpy(NewBuffer, Buffer, AllocationSize);
    return NewBuffer;
}
// not validated
void* callback_AllocateRuntimeCopyPool(UINTN AllocationSize, const void *Buffer, int cmock_num_calls) {
    return callback_AllocateCopyPool(AllocationSize, Buffer, cmock_num_calls);
}
// not validated
void* callback_AllocateReservedCopyPool(UINTN AllocationSize, const void *Buffer, int cmock_num_calls) {
    return callback_AllocateCopyPool(AllocationSize, Buffer, cmock_num_calls);
}
// not validated
void* callback_ReallocatePool(UINTN OldSize, UINTN NewSize, void *OldBuffer, int cmock_num_calls) {
    void *NewBuffer = malloc(NewSize);
    UINTN SmallerBufferSize = NewSize < OldSize ? NewSize : OldSize;
    if (NewSize > (MAX_ADDRESS - OldSize + 1)) {
        exit(-1);
    }
    if (OldBuffer != NULL) {
        memcpy(NewBuffer, OldBuffer, SmallerBufferSize);
    }
    return NewBuffer;
}
// not validated
void* callback_ReallocateRuntimePool(UINTN OldSize, UINTN NewSize, void *OldBuffer, int cmock_num_calls) {
    return callback_ReallocatePool(OldSize, NewSize, OldBuffer, cmock_num_calls);
}
// not validated
void* callback_ReallocateReservedPool(UINTN OldSize, UINTN NewSize, void *OldBuffer, int cmock_num_calls) {
    return callback_ReallocatePool(OldSize, NewSize, OldBuffer, cmock_num_calls);
}

// not validated
void callback_FreePool(void *p, int cmock_num_calls) {
    free(p);
}

void RegisterMemoryAllocationStubs() {
    AllocateZeroPool_StubWithCallback(callback_AllocateZeroPool);
    AllocatePages_StubWithCallback(callback_AllocatePages);
    AllocateRuntimePages_StubWithCallback(callback_AllocateRuntimePages);
    AllocateReservedPages_StubWithCallback(callback_AllocateReservedPages);
    FreePages_StubWithCallback(callback_FreePages);
    AllocateAlignedPages_StubWithCallback(callback_AllocateAlignedRuntimePages);
    AllocateAlignedRuntimePages_StubWithCallback(callback_AllocateAlignedRuntimePages);
    AllocateAlignedReservedPages_StubWithCallback(callback_AllocateAlignedReservedPages);
    FreeAlignedPages_StubWithCallback(callback_FreeAlignedPages);
    AllocatePool_StubWithCallback(callback_AllocatePool);
    AllocateRuntimePool_StubWithCallback(callback_AllocateRuntimePool);
    AllocateReservedPool_StubWithCallback(callback_AllocateReservedPool);
    AllocateRuntimeZeroPool_StubWithCallback(callback_AllocateRuntimeZeroPool);
    AllocateReservedZeroPool_StubWithCallback(callback_AllocateReservedZeroPool);
    AllocateCopyPool_StubWithCallback(callback_AllocateCopyPool);
    AllocateRuntimeCopyPool_StubWithCallback(callback_AllocateRuntimeCopyPool);
    AllocateReservedCopyPool_StubWithCallback(callback_AllocateReservedCopyPool);
    ReallocatePool_StubWithCallback(callback_ReallocatePool);
    ReallocateRuntimePool_StubWithCallback(callback_ReallocateRuntimePool);
    ReallocateReservedPool_StubWithCallback(callback_ReallocateReservedPool);
    FreePool_StubWithCallback(callback_FreePool);
}

void UnregisterMemoryAllocationStubs() {
    mock_MemoryAllocationLib_Destroy();
}