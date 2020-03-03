// © Copyright 2019-2020 HP Development Company, L.P.
// SPDX-License-Identifier: MIT

#include <PiSmm.h>
#include <mock_UefiSmmSystemTableFunctions.h>

extern EFI_SMM_SYSTEM_TABLE2  *gSmst;

void
InitializeSmmSystemTable(
   void
);

void
ResetSmmSystemTable(
   void
);

