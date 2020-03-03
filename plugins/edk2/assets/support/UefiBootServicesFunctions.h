// © Copyright 2019-2020 HP Development Company, L.P.
// SPDX-License-Identifier: MIT

EFI_TPL
MockRaiseTPL(
   IN EFI_TPL      NewTpl
  );

VOID
MockRestoreTPL(
  IN EFI_TPL      OldTpl
  );

EFI_STATUS
MockAllocatePages(
  IN     EFI_ALLOCATE_TYPE            Type,
  IN     EFI_MEMORY_TYPE              MemoryType,
  IN     UINTN                        Pages,
  IN OUT EFI_PHYSICAL_ADDRESS         *Memory
  );

EFI_STATUS
MockFreePages(
  IN  EFI_PHYSICAL_ADDRESS         Memory,
  IN  UINTN                        Pages
  );

EFI_STATUS
MockGetMemoryMap(
  IN OUT UINTN                       *MemoryMapSize,
  IN OUT EFI_MEMORY_DESCRIPTOR       *MemoryMap,
  OUT    UINTN                       *MapKey,
  OUT    UINTN                       *DescriptorSize,
  OUT    UINT32                      *DescriptorVersion
  );

EFI_STATUS
MockAllocatePool(
  IN  EFI_MEMORY_TYPE              PoolType,
  IN  UINTN                        Size,
  OUT VOID                         **Buffer
  );

EFI_STATUS
MockFreePool(
  IN  VOID                         *Buffer
  );

EFI_STATUS
MockCreateEvent(
  IN  UINT32                       Type,
  IN  EFI_TPL                      NotifyTpl,
  IN  EFI_EVENT_NOTIFY             NotifyFunction,
  IN  VOID                         *NotifyContext,
  OUT EFI_EVENT                    *Event
  );

EFI_STATUS
MockSetTimer(
  IN  EFI_EVENT                Event,
  IN  EFI_TIMER_DELAY          Type,
  IN  UINT64                   TriggerTime
  );

EFI_STATUS
MockWaitForEvent(
  IN  UINTN                    NumberOfEvents,
  IN  EFI_EVENT                *Event,
  OUT UINTN                    *Index
  );

EFI_STATUS
MockSignalEvent(
  IN  EFI_EVENT                Event
  );

EFI_STATUS
MockCloseEvent(
  IN EFI_EVENT                Event
  );

EFI_STATUS
MockCheckEvent(
  IN EFI_EVENT                Event
  );

EFI_STATUS
MockInstallProtocolInterface(
  IN OUT EFI_HANDLE               *Handle,
  IN     EFI_GUID                 *Protocol,
  IN     EFI_INTERFACE_TYPE       InterfaceType,
  IN     VOID                     *Interface
  );

EFI_STATUS
MockReinstallProtocolInterface(
  IN EFI_HANDLE               Handle,
  IN EFI_GUID                 *Protocol,
  IN VOID                     *OldInterface,
  IN VOID                     *NewInterface
  );

EFI_STATUS
MockUninstallProtocolInterface(
  IN EFI_HANDLE               Handle,
  IN EFI_GUID                 *Protocol,
  IN VOID                     *Interface
  );

EFI_STATUS
MockHandleProtocol(
  IN  EFI_HANDLE               Handle,
  IN  EFI_GUID                 *Protocol,
  OUT VOID                     **Interface
  );

EFI_STATUS
MockRegisterProtocolNotify(
  IN  EFI_GUID                 *Protocol,
  IN  EFI_EVENT                Event,
  OUT VOID                     **Registration
  );

EFI_STATUS
MockLocateHandle(
  IN     EFI_LOCATE_SEARCH_TYPE   SearchType,
  IN     EFI_GUID                 *Protocol,    OPTIONAL
  IN     VOID                     *SearchKey,   OPTIONAL
  IN OUT UINTN                    *BufferSize,
  OUT    EFI_HANDLE               *Buffer
  );

EFI_STATUS
MockLocateDevicePath(
  IN     EFI_GUID                         *Protocol,
  IN OUT EFI_DEVICE_PATH_PROTOCOL         **DevicePath,
  OUT    EFI_HANDLE                       *Device
  );

EFI_STATUS
MockInstallConfigurationTable(
  IN EFI_GUID                 *Guid,
  IN VOID                     *Table
  );

EFI_STATUS
MockLoadImage(
  IN  BOOLEAN                      BootPolicy,
  IN  EFI_HANDLE                   ParentImageHandle,
  IN  EFI_DEVICE_PATH_PROTOCOL     *DevicePath,
  IN  VOID                         *SourceBuffer OPTIONAL,
  IN  UINTN                        SourceSize,
  OUT EFI_HANDLE                   *ImageHandle
  );

EFI_STATUS
MockStartImage(
  IN  EFI_HANDLE                  ImageHandle,
  OUT UINTN                       *ExitDataSize,
  OUT CHAR16                      **ExitData    OPTIONAL
  );

EFI_STATUS
MockExit(
  IN  EFI_HANDLE                   ImageHandle,
  IN  EFI_STATUS                   ExitStatus,
  IN  UINTN                        ExitDataSize,
  IN  CHAR16                       *ExitData     OPTIONAL
  );

EFI_STATUS
MockUnloadImage(
  IN  EFI_HANDLE                   ImageHandle
  );

EFI_STATUS
MockExitBootServices(
  IN  EFI_HANDLE                   ImageHandle,
  IN  UINTN                        MapKey
  );

EFI_STATUS
MockGetNextMonotonicCount(
  OUT UINT64                  *Count
  );

EFI_STATUS
MockStall(
  IN  UINTN                    Microseconds
  );

EFI_STATUS
MockSetWatchdogTimer(
  IN UINTN                    Timeout,
  IN UINT64                   WatchdogCode,
  IN UINTN                    DataSize,
  IN CHAR16                   *WatchdogData OPTIONAL
  );

EFI_STATUS
MockConnectController(
  IN  EFI_HANDLE                    ControllerHandle,
  IN  EFI_HANDLE                    *DriverImageHandle,   OPTIONAL
  IN  EFI_DEVICE_PATH_PROTOCOL      *RemainingDevicePath, OPTIONAL
  IN  BOOLEAN                       Recursive
  );

EFI_STATUS
MockDisconnectController(
  IN  EFI_HANDLE                     ControllerHandle,
  IN  EFI_HANDLE                     DriverImageHandle, OPTIONAL
  IN  EFI_HANDLE                     ChildHandle        OPTIONAL
  );

EFI_STATUS
MockOpenProtocol(
  IN  EFI_HANDLE                Handle,
  IN  EFI_GUID                  *Protocol,
  OUT VOID                      **Interface, OPTIONAL
  IN  EFI_HANDLE                AgentHandle,
  IN  EFI_HANDLE                ControllerHandle,
  IN  UINT32                    Attributes
  );

EFI_STATUS
MockCloseProtocol(
  IN EFI_HANDLE               Handle,
  IN EFI_GUID                 *Protocol,
  IN EFI_HANDLE               AgentHandle,
  IN EFI_HANDLE               ControllerHandle
  );

EFI_STATUS
MockOpenProtocolInformation(
  IN  EFI_HANDLE                          Handle,
  IN  EFI_GUID                            *Protocol,
  OUT EFI_OPEN_PROTOCOL_INFORMATION_ENTRY **EntryBuffer,
  OUT UINTN                               *EntryCount
  );

EFI_STATUS
MockProtocolsPerHandle(
  IN  EFI_HANDLE      Handle,
  OUT EFI_GUID        ***ProtocolBuffer,
  OUT UINTN           *ProtocolBufferCount
  );

EFI_STATUS
MockLocateHandleBuffer(
  IN     EFI_LOCATE_SEARCH_TYPE       SearchType,
  IN     EFI_GUID                     *Protocol,      OPTIONAL
  IN     VOID                         *SearchKey,     OPTIONAL
  IN OUT UINTN                        *NoHandles,
  OUT    EFI_HANDLE                   **Buffer
  );

EFI_STATUS
MockLocateProtocol(
  IN  EFI_GUID  *Protocol,
  IN  VOID      *Registration, OPTIONAL
  OUT VOID      **Interface
  );

EFI_STATUS
MockInstallMultipleProtocolInterfaces(
  IN OUT EFI_HANDLE           *Handle,
  ...
  );

EFI_STATUS
MockUninstallMultipleProtocolInterfaces(
  IN EFI_HANDLE           Handle,
  ...
  );

EFI_STATUS
MockCalculateCrc32(
  IN  VOID                              *Data,
  IN  UINTN                             DataSize,
  OUT UINT32                            *Crc32
  );

VOID
MockCopyMem(
  IN VOID     *Destination,
  IN VOID     *Source,
  IN UINTN    Length
  );

VOID
MockSetMem(
  IN VOID     *Buffer,
  IN UINTN    Size,
  IN UINT8    Value
  );

EFI_STATUS
MockCreateEventEx(
  IN       UINT32                 Type,
  IN       EFI_TPL                NotifyTpl,
  IN       EFI_EVENT_NOTIFY       NotifyFunction OPTIONAL,
  IN CONST VOID                   *NotifyContext OPTIONAL,
  IN CONST EFI_GUID               *EventGroup    OPTIONAL,
  OUT      EFI_EVENT              *Event
  );
