#include "unity.h"
#include "CeedlingDxeServices.h"

EFI_TABLE_HEADER        Hdr;
VOID                    *Reserved = NULL;

EFI_HANDLE              gImageHandle = NULL;

EFI_BOOT_SERVICES       *gBS = NULL;
EFI_RUNTIME_SERVICES    *gRT = NULL;
EFI_SYSTEM_TABLE        *gST = NULL;

EFI_BOOT_SERVICES       TestBootService;
EFI_RUNTIME_SERVICES    TestRuntimeServices;
EFI_SYSTEM_TABLE        TestSystemTable;

void
InitializeDxeGlobalServices(
   void
)
{
   // Only call system table, since it'll initialize all three.
   InitializeSystemTable();
}

void
InitializeBootServices(
   void
)
{
   TestBootService.Hdr = Hdr;
   TestBootService.RaiseTPL = MockRaiseTPL;
   TestBootService.RestoreTPL = MockRestoreTPL;
   TestBootService.AllocatePages = MockAllocatePages;
   TestBootService.FreePages = MockFreePages;
   TestBootService.GetMemoryMap = MockGetMemoryMap;
   TestBootService.AllocatePool = MockAllocatePool;
   TestBootService.FreePool = MockFreePool;
   TestBootService.CreateEvent = MockCreateEvent;
   TestBootService.SetTimer = MockSetTimer;
   TestBootService.WaitForEvent = MockWaitForEvent;
   TestBootService.SignalEvent = MockSignalEvent;
   TestBootService.CloseEvent = MockCloseEvent;
   TestBootService.CheckEvent = MockCheckEvent;
   TestBootService.InstallProtocolInterface = MockInstallProtocolInterface;
   TestBootService.ReinstallProtocolInterface = MockReinstallProtocolInterface;
   TestBootService.UninstallProtocolInterface = MockUninstallProtocolInterface;
   TestBootService.HandleProtocol = MockHandleProtocol;
   TestBootService.Reserved = Reserved;
   TestBootService.RegisterProtocolNotify = MockRegisterProtocolNotify;
   TestBootService.LocateHandle = MockLocateHandle;
   TestBootService.LocateDevicePath = MockLocateDevicePath;
   TestBootService.InstallConfigurationTable = MockInstallConfigurationTable;
   TestBootService.LoadImage = MockLoadImage;
   TestBootService.StartImage = MockStartImage;
   TestBootService.Exit = MockExit;
   TestBootService.UnloadImage = MockUnloadImage;
   TestBootService.ExitBootServices = MockExitBootServices;
   TestBootService.GetNextMonotonicCount = MockGetNextMonotonicCount;
   TestBootService.Stall = MockStall;
   TestBootService.SetWatchdogTimer = MockSetWatchdogTimer;
   TestBootService.ConnectController = MockConnectController;
   TestBootService.DisconnectController = MockDisconnectController;
   TestBootService.OpenProtocol = MockOpenProtocol;
   TestBootService.CloseProtocol = MockCloseProtocol;
   TestBootService.OpenProtocolInformation = MockOpenProtocolInformation;
   TestBootService.ProtocolsPerHandle = MockProtocolsPerHandle;
   TestBootService.LocateHandleBuffer = MockLocateHandleBuffer;
   TestBootService.LocateProtocol = MockLocateProtocol;
   TestBootService.InstallMultipleProtocolInterfaces = MockInstallMultipleProtocolInterfaces;
   TestBootService.UninstallMultipleProtocolInterfaces = MockUninstallMultipleProtocolInterfaces;
   TestBootService.CalculateCrc32 = MockCalculateCrc32;
   TestBootService.CopyMem = MockCopyMem;
   TestBootService.SetMem = MockSetMem;
   TestBootService.CreateEventEx = MockCreateEventEx;

   gBS = &TestBootService;
}

void
InitializeRuntimeServices(
   void
)
{
   TestRuntimeServices.Hdr = Hdr;
   TestRuntimeServices.GetTime = MockGetTime;
   TestRuntimeServices.SetTime = MockSetTime;
   TestRuntimeServices.GetWakeupTime = MockGetWakeupTime;
   TestRuntimeServices.SetWakeupTime = MockSetWakeupTime;
   TestRuntimeServices.SetVirtualAddressMap = MockSetVirtualAddressMap;
   TestRuntimeServices.ConvertPointer = MockConvertPointer;
   TestRuntimeServices.GetVariable = MockGetVariable;
   TestRuntimeServices.GetNextVariableName = MockGetNextVariableName;
   TestRuntimeServices.SetVariable = MockSetVariable;
   TestRuntimeServices.GetNextHighMonotonicCount = MockGetNextHighMonotonicCount;
   TestRuntimeServices.ResetSystem = MockResetSystem;
   TestRuntimeServices.UpdateCapsule = MockUpdateCapsule;
   TestRuntimeServices.QueryCapsuleCapabilities = MockQueryCapsuleCapabilities;
   TestRuntimeServices.QueryVariableInfo = MockQueryVariableInfo;

   gRT = &TestRuntimeServices;
}

void
InitializeSystemTable(
   void
)
{
   // Since gST actually contains gRT and gBS, initialize them both here.
   InitializeRuntimeServices();
   InitializeBootServices();

   TestSystemTable.Hdr = Hdr;
   TestSystemTable.FirmwareVendor = L"HP";
   TestSystemTable.FirmwareRevision = 0u;
   TestSystemTable.ConsoleInHandle = NULL;
   TestSystemTable.ConIn = NULL;
   TestSystemTable.ConsoleOutHandle = NULL;
   TestSystemTable.ConOut = NULL;
   TestSystemTable.StandardErrorHandle = NULL;
   TestSystemTable.StdErr = NULL;
   TestSystemTable.RuntimeServices = &TestRuntimeServices;
   TestSystemTable.BootServices = &TestBootService;
   TestSystemTable.NumberOfTableEntries = 0;
   TestSystemTable.ConfigurationTable = NULL;

   gST = &TestSystemTable;
}

void
ResetDxeGlobalServices(
   void
)
{
   gBS = NULL;
   gRT = NULL;
   gST = NULL;
}

void
ResetBootServices(
   void
)
{
   gBS = NULL;
}

void
ResetRuntimeServices(
   void
)
{
   gRT = NULL;
}

void
ResetSystemTable(
   void
)
{
   gST = NULL;
}
