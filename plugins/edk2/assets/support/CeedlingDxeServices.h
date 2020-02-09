#include "mock_UefiBootServicesFunctions.h"
#include "mock_UefiRuntimeServicesFunctions.h"

extern EFI_HANDLE         gImageHandle;

extern EFI_BOOT_SERVICES      *gBS;
extern EFI_RUNTIME_SERVICES   *gRT;
extern EFI_SYSTEM_TABLE       *gST;

void
InitializeDxeGlobalServices(
   void
);

void
InitializeBootServices(
   void
);

void
InitializeRuntimeServices(
   void
);

void
InitializeSystemTable(
   void
);

void
ResetDxeGlobalServices(
   void
);

void
ResetBootServices(
   void
);

void
ResetRuntimeServices(
   void
);

void
ResetSystemTable(
   void
);
