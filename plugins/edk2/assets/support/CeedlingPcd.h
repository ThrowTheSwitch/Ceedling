#include <PcdLib.h>

#ifdef PcdToken
#undef PcdToken
UINTN  PcdToken(int Token);
#endif

#ifdef  FeaturePcdGet
#undef  FeaturePcdGet
BOOLEAN FeaturePcdGet(int Token);
#endif

#ifdef FeaturePcdGet8
#undef FeaturePcdGet8
UINT8  FeaturePcdGet8(int Token);
#endif

#ifdef FixedPcdGet8
#undef FixedPcdGet8
UINT8  FixedPcdGet8(int Token);
#endif

#ifdef FixedPcdGet16
#undef FixedPcdGet16
UINT16 FixedPcdGet16(int Token);
#endif

#ifdef FixedPcdGet32
#undef FixedPcdGet32
UINT32 FixedPcdGet32(int Token);
#endif

#ifdef FixedPcdGet64
#undef FixedPcdGet64
UINT64 FixedPcdGet64(int Token);
#endif

#ifdef  FixedPcdGetBool
#undef  FixedPcdGetBool
BOOLEAN FixedPcdGetBool(int Token);
#endif

#ifdef FixedPcdGetPtr
#undef FixedPcdGetPtr
VOID * FixedPcdGetPtr(int Token);
#endif

#ifdef PatchPcdGet8
#undef PatchPcdGet8
UINT8  PatchPcdGet8(int Token);
#endif

#ifdef PatchPcdGet16
#undef PatchPcdGet16
UINT16 PatchPcdGet16(int Token);
#endif

#ifdef PatchPcdGet32
#undef PatchPcdGet32
UINT32 PatchPcdGet32(int Token);
#endif

#ifdef PatchPcdGet64
#undef PatchPcdGet64
UINT64 PatchPcdGet64(int Token);
#endif

#ifdef  PatchPcdGetBool
#undef  PatchPcdGetBool
BOOLEAN PatchPcdGetBool(int Token);
#endif

#ifdef PatchPcdGetPtr
#undef PatchPcdGetPtr
VOID * PatchPcdGetPtr(int Token);
#endif

#ifdef PatchPcdSet8
#undef PatchPcdSet8
UINT8  PatchPcdSet8(int Token, UINT8 Value);
#endif

#ifdef PatchPcdSet16
#undef PatchPcdSet16
UINT16 PatchPcdSet16(int Token, UINT16 Value);
#endif

#ifdef PatchPcdSet32
#undef PatchPcdSet32
UINT32 PatchPcdSet32(int Token, UINT32 Value);
#endif

#ifdef PatchPcdSet64
#undef PatchPcdSet64
UINT64 PatchPcdSet64(int Token, UINT64 Value);
#endif

#ifdef  PatchPcdSetBool
#undef  PatchPcdSetBool
BOOLEAN PatchPcdSetBool(int Token, BOOLEAN Value);
#endif

#ifdef PatchPcdSetPtr
#undef PatchPcdSetPtr
VOID * PatchPcdSetPtr(int Token, VOID * Value);
#endif

#ifdef PcdGet8
#undef PcdGet8
UINT8  PcdGet8(int Token);
#endif

#ifdef PcdGet16
#undef PcdGet16
UINT16 PcdGet16(int Token);
#endif

#ifdef PcdGet32
#undef PcdGet32
UINT32 PcdGet32(int Token);
#endif

#ifdef PcdGet64
#undef PcdGet64
UINT64 PcdGet64(int Token);
#endif

#ifdef  PcdGetBool
#undef  PcdGetBool
BOOLEAN PcdGetBool(int Token);
#endif

#ifdef PcdGetPtr
#undef PcdGetPtr
VOID * PcdGetPtr(int Token);
#endif

#ifdef FixedPcdGetSize
#undef FixedPcdGetSize
UINTN  FixedPcdGetSize(int Token);
#endif

#ifdef PatchPcdGetSize
#undef PatchPcdGetSize
UINTN  PatchPcdGetSize(int Token);
#endif

#ifdef PcdGetSize
#undef PcdGetSize
UINTN  PcdGetSize(int Token);
#endif

#ifdef PcdGetExSize
#undef PcdGetExSize
UINTN PcdGetExSize(GUID Guid, int Token);
#endif

#undef PcdSet8
#ifdef PcdSet8
UINT8  PcdSet8(int Token, UINT8 Value);
#endif

#ifdef PcdSet16
#undef PcdSet16
UINT16 PcdSet16(int Token, UINT16 Value);
#endif

#ifdef PcdSet32
#undef PcdSet32
UINT32 PcdSet32(int Token, UINT32 Value);
#endif

#ifdef PcdSet64
#undef PcdSet64
UINT64 PcdSet64(int Token, UINT64 Value);
#endif

#ifdef  PcdSetBool
#undef  PcdSetBool
BOOLEAN PcdSetBool(int Token, BOOLEAN Value);
#endif

#ifdef PcdSetPtr
#undef PcdSetPtr
VOID * PcdSetPtr(int Token, VOID * Value);
#endif

#undef PcdSet8S
#ifdef PcdSet8S
UINT8  PcdSet8S(int Token, UINT8 Value);
#endif

#ifdef PcdSet16S
#undef PcdSet16S
UINT16 PcdSet16S(int Token, UINT16 Value);
#endif

#ifdef PcdSet32S
#undef PcdSet32S
UINT32 PcdSet32S(int Token, UINT32 Value);
#endif

#ifdef PcdSet64S
#undef PcdSet64S
UINT64 PcdSet64S(int Token, UINT64 Value);
#endif

#ifdef  PcdSetBoolS
#undef  PcdSetBoolS
BOOLEAN PcdSetBoolS(int Token, BOOLEAN Value);
#endif

#ifdef PcdSetPtrS
#undef PcdSetPtrS
VOID * PcdSetPtrS(int Token, VOID * Value);
#endif

#ifdef PcdTokenEx
#undef PcdTokenEx
UINTN  PcdTokenEx(GUID *Guid, int Token);
#endif

#ifdef PcdGet8Ex
#undef PcdGet8Ex
UINT8  PcdGet8Ex(GUID Guid, int Token);
#endif

#ifdef PcdGet16Ex
#undef PcdGet16Ex
UINT16 PcdGet16Ex(GUID Guid, int Token);
#endif

#ifdef PcdGet32Ex
#undef PcdGet32Ex
UINT32 PcdGet32Ex(GUID Guid, int Token);
#endif

#ifdef PcdGet64Ex
#undef PcdGet64Ex
UINT64 PcdGet64Ex(GUID Guid, int Token);
#endif

#ifdef  PcdGetBoolEx
#undef  PcdGetBoolEx
BOOLEAN PcdGetBoolEx(GUID Guid, int Token);
#endif

#ifdef PcdGetPtrEx
#undef PcdGetPtrEx
VOID * PcdGetPtrEx(GUID Guid, int Token);
#endif

#undef PcdSet8Ex
#ifdef PcdSet8Ex
UINT8  PcdSet8Ex(GUID Guid, int Token, UINT8 Value);
#endif

#ifdef PcdSet16Ex
#undef PcdSet16Ex
UINT16 PcdSet16Ex(GUID Guid, int Token, UINT16 Value);
#endif

#ifdef PcdSet32Ex
#undef PcdSet32Ex
UINT32 PcdSet32Ex(GUID Guid, int Token, UINT32 Value);
#endif

#ifdef PcdSet64Ex
#undef PcdSet64Ex
UINT64 PcdSet64Ex(GUID Guid, int Token, UINT64 Value);
#endif

#ifdef  PcdSetBoolEx
#undef  PcdSetBoolEx
BOOLEAN PcdSetBoolEx(GUID Guid, int Token, BOOLEAN Value);
#endif

#ifdef PcdSetPtrEx
#undef PcdSetPtrEx
VOID * PcdSetPtrEx(GUID Guid, int Token, VOID * Value);
#endif

#undef PcdSet8SEx
#ifdef PcdSet8SEx
UINT8  PcdSet8SEx(GUID Guid, int Token, UINT8 Value);
#endif

#ifdef PcdSet16SEx
#undef PcdSet16SEx
UINT16 PcdSet16SEx(GUID Guid, int Token, UINT16 Value);
#endif

#ifdef PcdSet32SEx
#undef PcdSet32SEx
UINT32 PcdSet32SEx(GUID Guid, int Token, UINT32 Value);
#endif

#ifdef PcdSet64SEx
#undef PcdSet64SEx
UINT64 PcdSet64SEx(GUID Guid, int Token, UINT64 Value);
#endif

#ifdef  PcdSetBoolSEx
#undef  PcdSetBoolSEx
BOOLEAN PcdSetBoolSEx(GUID Guid, int Token, BOOLEAN Value);
#endif

#ifdef PcdSetPtrSEx
#undef PcdSetPtrSEx
VOID * PcdSetPtrSEx(GUID Guid, int Token, VOID * Value);
#endif

