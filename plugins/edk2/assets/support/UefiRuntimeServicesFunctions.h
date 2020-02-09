EFI_STATUS
MockGetTime(
  OUT  EFI_TIME                    *Time,
  OUT  EFI_TIME_CAPABILITIES       *Capabilities OPTIONAL
  );

EFI_STATUS
MockSetTime(
  IN  EFI_TIME                     *Time
  );

EFI_STATUS
MockGetWakeupTime(
  OUT BOOLEAN                     *Enabled,
  OUT BOOLEAN                     *Pending,
  OUT EFI_TIME                    *Time
  );

EFI_STATUS
MockSetWakeupTime(
  IN  BOOLEAN                      Enable,
  IN  EFI_TIME                     *Time   OPTIONAL
  );

EFI_STATUS
MockSetVirtualAddressMap(
  IN  UINTN                        MemoryMapSize,
  IN  UINTN                        DescriptorSize,
  IN  UINT32                       DescriptorVersion,
  IN  EFI_MEMORY_DESCRIPTOR        *VirtualMap
  );

EFI_STATUS
MockConvertPointer(
  IN     UINTN                      DebugDisposition,
  IN OUT VOID                       **Address
  );

EFI_STATUS
MockGetVariable(
  IN     CHAR16                      *VariableName,
  IN     EFI_GUID                    *VendorGuid,
  OUT    UINT32                      *Attributes,    OPTIONAL
  IN OUT UINTN                       *DataSize,
  OUT    VOID                        *Data           OPTIONAL
  );

EFI_STATUS
MockGetNextVariableName(
  IN OUT UINTN                    *VariableNameSize,
  IN OUT CHAR16                   *VariableName,
  IN OUT EFI_GUID                 *VendorGuid
  );

EFI_STATUS
MockSetVariable(
  IN  CHAR16                       *VariableName,
  IN  EFI_GUID                     *VendorGuid,
  IN  UINT32                       Attributes,
  IN  UINTN                        DataSize,
  IN  VOID                         *Data
  );

EFI_STATUS
MockGetNextHighMonotonicCount(
  OUT UINT32                  *HighCount
  );

VOID
MockResetSystem(
  IN EFI_RESET_TYPE           ResetType,
  IN EFI_STATUS               ResetStatus,
  IN UINTN                    DataSize,
  IN VOID                     *ResetData OPTIONAL
  );

EFI_STATUS
MockUpdateCapsule(
  IN EFI_CAPSULE_HEADER     **CapsuleHeaderArray,
  IN UINTN                  CapsuleCount,
  IN EFI_PHYSICAL_ADDRESS   ScatterGatherList   OPTIONAL
  );

EFI_STATUS
MockQueryCapsuleCapabilities(
  IN  EFI_CAPSULE_HEADER     **CapsuleHeaderArray,
  IN  UINTN                  CapsuleCount,
  OUT UINT64                 *MaximumCapsuleSize,
  OUT EFI_RESET_TYPE         *ResetType
  );

EFI_STATUS
MockQueryVariableInfo(
  IN  UINT32            Attributes,
  OUT UINT64            *MaximumVariableStorageSize,
  OUT UINT64            *RemainingVariableStorageSize,
  OUT UINT64            *MaximumVariableSize
  );
