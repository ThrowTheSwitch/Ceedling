// © Copyright 2019-2020 HP Development Company, L.P.
// SPDX-License-Identifier: MIT

#include "unity.h"
#include "CeedlingSmmServices.h"

EFI_TABLE_HEADER        Hdr;
VOID                    *Reserved = NULL;
EFI_SMM_CPU_IO2_PROTOCOL DummySmmIoProtocol;

EFI_SMM_SYSTEM_TABLE2   *gSmst = NULL;

EFI_SMM_SYSTEM_TABLE2   TestSmmSystemTable;

void
InitializeSmmSystemTable(
   void
)
{
   TestSmmSystemTable.Hdr = Hdr;
   TestSmmSystemTable.SmmFirmwareVendor = L"HP";
   TestSmmSystemTable.SmmFirmwareRevision = 0u;
   TestSmmSystemTable.SmmInstallConfigurationTable = MockSmmInstallConfigurationTable;
   TestSmmSystemTable.SmmIo = DummySmmIoProtocol;
   TestSmmSystemTable.SmmAllocatePool = MockSmmAllocatePool;
   TestSmmSystemTable.SmmFreePool = MockSmmFreePool;
   TestSmmSystemTable.SmmAllocatePages = MockSmmAllocatePages;
   TestSmmSystemTable.SmmFreePages = MockSmmFreePages;
   TestSmmSystemTable.SmmStartupThisAp = MockSmmStartupThisAp;
   TestSmmSystemTable.CurrentlyExecutingCpu = 0u;
   TestSmmSystemTable.NumberOfCpus = 1u;
   TestSmmSystemTable.CpuSaveStateSize = NULL;
   TestSmmSystemTable.CpuSaveState = NULL;
   TestSmmSystemTable.NumberOfTableEntries = 0u;
   TestSmmSystemTable.SmmConfigurationTable = NULL;
   TestSmmSystemTable.SmmInstallProtocolInterface = MockSmmInstallProtocolInterface;
   TestSmmSystemTable.SmmUninstallProtocolInterface = MockSmmUninstallProtocolInterface;
   TestSmmSystemTable.SmmHandleProtocol = MockSmmHandleProtocol;
   TestSmmSystemTable.SmmRegisterProtocolNotify = MockSmmRegisterProtocolNotify;
   TestSmmSystemTable.SmmLocateHandle = MockSmmLocateHandle;
   TestSmmSystemTable.SmmLocateProtocol = MockSmmLocateProtocol;
   TestSmmSystemTable.SmiManage = MockSmiManage;
   TestSmmSystemTable.SmiHandlerRegister = MockSmiHandlerRegister;
   TestSmmSystemTable.SmiHandlerUnRegister = MockSmiHandlerUnRegister;

   gSmst = &TestSmmSystemTable;
}

void
ResetSmmSystemTable(
   void
)
{
   gSmst = NULL;
}
