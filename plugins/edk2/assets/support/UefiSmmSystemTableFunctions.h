#include <PiSmm.h>

EFI_STATUS
MockSmmInstallConfigurationTable(
  IN CONST EFI_SMM_SYSTEM_TABLE2  *SystemTable,
  IN CONST EFI_GUID               *Guid,
  IN VOID                         *Table,
  IN UINTN                        TableSize
  );

EFI_STATUS
MockSmmAllocatePool(
  IN  EFI_MEMORY_TYPE              PoolType,
  IN  UINTN                        Size,
  OUT VOID                         **Buffer
  );

EFI_STATUS
MockSmmFreePool(
  IN  VOID                         *Buffer
  );

EFI_STATUS
MockSmmAllocatePages(
  IN     EFI_ALLOCATE_TYPE            Type,
  IN     EFI_MEMORY_TYPE              MemoryType,
  IN     UINTN                        Pages,
  IN OUT EFI_PHYSICAL_ADDRESS         *Memory
  );

EFI_STATUS
MockSmmFreePages(
  IN  EFI_PHYSICAL_ADDRESS         Memory,
  IN  UINTN                        Pages
  );

EFI_STATUS
MockSmmStartupThisAp(
  IN EFI_AP_PROCEDURE  Procedure,
  IN UINTN             CpuNumber,
  IN OUT VOID          *ProcArguments OPTIONAL
  );

EFI_STATUS
MockSmmInstallProtocolInterface(
  IN OUT EFI_HANDLE               *Handle,
  IN     EFI_GUID                 *Protocol,
  IN     EFI_INTERFACE_TYPE       InterfaceType,
  IN     VOID                     *Interface
  );

EFI_STATUS
MockSmmUninstallProtocolInterface(
  IN EFI_HANDLE               Handle,
  IN EFI_GUID                 *Protocol,
  IN VOID                     *Interface
  );

EFI_STATUS
MockSmmHandleProtocol(
  IN  EFI_HANDLE               Handle,
  IN  EFI_GUID                 *Protocol,
  OUT VOID                     **Interface
  );

EFI_STATUS
MockSmmRegisterProtocolNotify(
  IN  CONST EFI_GUID     *Protocol,
  IN  EFI_SMM_NOTIFY_FN  Function,
  OUT VOID               **Registration
  );

EFI_STATUS
MockSmmLocateHandle(
  IN     EFI_LOCATE_SEARCH_TYPE   SearchType,
  IN     EFI_GUID                 *Protocol,    OPTIONAL
  IN     VOID                     *SearchKey,   OPTIONAL
  IN OUT UINTN                    *BufferSize,
  OUT    EFI_HANDLE               *Buffer
  );

EFI_STATUS
MockSmmLocateProtocol(
  IN  EFI_GUID  *Protocol,
  IN  VOID      *Registration, OPTIONAL
  OUT VOID      **Interface
  );

EFI_STATUS
MockSmiManage(
  IN CONST EFI_GUID  *HandlerType,
  IN CONST VOID      *Context         OPTIONAL,
  IN OUT VOID        *CommBuffer      OPTIONAL,
  IN OUT UINTN       *CommBufferSize  OPTIONAL
  );

EFI_STATUS
MockSmiHandlerRegister(
  IN  EFI_SMM_HANDLER_ENTRY_POINT2  Handler,
  IN  CONST EFI_GUID                *HandlerType OPTIONAL,
  OUT EFI_HANDLE                    *DispatchHandle
  );

EFI_STATUS
MockSmiHandlerUnRegister(
  IN EFI_HANDLE  DispatchHandle
  );
