#ifndef _VS_EFI_H_
#define _VS_EFI_H_


  //
  // use Microsoft C complier dependent integer width types 
  //
#include <stdio.h>
#include <string.h>
#include <stdlib.h>



//
// Processor specific defines
//



  ///
  /// 8-byte unsigned value
  ///
  typedef  unsigned __int64    UINT64;
  ///
  /// 8-byte signed value
  ///
  typedef __int64             INT64;
  ///
  /// 4-byte unsigned value
  ///
  typedef  unsigned __int32    UINT32;
  ///
  /// 4-byte signed value
  ///
  typedef __int32             INT32;
  ///
  /// 2-byte unsigned value
  ///
  typedef unsigned short      UINT16;
  ///
  /// 2-byte Character.  Unless otherwise specified all strings are stored in the
  /// UTF-16 encoding format as defined by Unicode 2.1 and ISO/IEC 10646 standards.
  ///
  //typedef unsigned short      CHAR16;
  typedef wchar_t CHAR16;
  ///
  /// 2-byte signed value
  ///
  typedef short               INT16;
  ///
  /// Logical Boolean.  1-byte value containing 0 for FALSE or a 1 for TRUE.  Other
  /// values are undefined.
  ///
  typedef unsigned char       BOOLEAN;
  ///
  /// 1-byte unsigned value
  ///
  typedef unsigned char       UINT8;
  ///
  /// 1-byte Character
  ///
  typedef char                CHAR8;
  ///
  /// 1-byte signed value
  ///
  typedef char                INT8;

  typedef UINT64 UINTN;
  typedef INT64 INTN;

  typedef UINT64 EFI_STATUS;

  typedef void                VOID;

  typedef VOID*               EFI_HANDLE;

  typedef VOID*               EFI_SYSTEM_TABLE;

///
/// A value of native width with the highest bit set.
///
#define MAX_BIT     0x80000000
///
/// A value of native width with the two highest bits set.
///
#define MAX_2_BITS  0xC0000000

///
/// Maximum legal IA-32 address.
///
#define MAX_ADDRESS   0xFFFFFFFF

///
/// Maximum values for common UEFI Data Types
///
#define MAX_INT8    ((INT8)0x7F)
#define MAX_UINT8   ((UINT8)0xFF)
#define MAX_INT16   ((INT16)0x7FFF)
#define MAX_UINT16  ((UINT16)0xFFFF)
#define MAX_INT32   ((INT32)0x7FFFFFFF)
#define MAX_UINT32  ((UINT32)0xFFFFFFFF)
#define MAX_INT64   ((INT64)0x7FFFFFFFFFFFFFFF)
#define MAX_UINT64  ((UINT64)0xFFFFFFFFFFFFFFFF)

typedef struct {
  UINT32  Data1;
  UINT16  Data2;
  UINT16  Data3;
  UINT8   Data4[8];
} EFI_GUID;

#define FALSE 0
#define TRUE 1

#define IN
#define OUT
#define OPTIONAL
#define CONST const
#define STATIC static
#define EFIAPI

//#define EFI_D_ERROR     0x80000000  // Error
//#define EFI_D_INFO      0x00000040          // Informational debug messages
//
// Status codes common to all execution phases
//
typedef UINTN RETURN_STATUS;

/**
  Produces a RETURN_STATUS code with the highest bit set.

  @param  StatusCode    The status code value to convert into a warning code.
                        StatusCode must be in the range 0x00000000..0x7FFFFFFF.

  @return The value specified by StatusCode with the highest bit set.

**/
#define ENCODE_ERROR(StatusCode)     ((RETURN_STATUS)(MAX_BIT | (StatusCode)))

/**
  Produces a RETURN_STATUS code with the highest bit clear.

  @param  StatusCode    The status code value to convert into a warning code.
                        StatusCode must be in the range 0x00000000..0x7FFFFFFF.

  @return The value specified by StatusCode with the highest bit clear.

**/
#define ENCODE_WARNING(StatusCode)   ((RETURN_STATUS)(StatusCode))

/**
  Returns TRUE if a specified RETURN_STATUS code is an error code.

  This function returns TRUE if StatusCode has the high bit set.  Otherwise, FALSE is returned.

  @param  StatusCode    The status code value to evaluate.

  @retval TRUE          The high bit of StatusCode is set.
  @retval FALSE         The high bit of StatusCode is clear.

**/
#define RETURN_ERROR(StatusCode)     (((INTN)(RETURN_STATUS)(StatusCode)) < 0)

///
/// The operation completed successfully.
///
#define RETURN_SUCCESS               0

///
/// The image failed to load.
///
#define RETURN_LOAD_ERROR            ENCODE_ERROR (1)

///
/// The parameter was incorrect.
///
#define RETURN_INVALID_PARAMETER     ENCODE_ERROR (2)

///
/// The operation is not supported.
///
#define RETURN_UNSUPPORTED           ENCODE_ERROR (3)

///
/// The buffer was not the proper size for the request.
///
#define RETURN_BAD_BUFFER_SIZE       ENCODE_ERROR (4)

///
/// The buffer was not large enough to hold the requested data.
/// The required buffer size is returned in the appropriate
/// parameter when this error occurs.
///
#define RETURN_BUFFER_TOO_SMALL      ENCODE_ERROR (5)

///
/// There is no data pending upon return.
///
#define RETURN_NOT_READY             ENCODE_ERROR (6)

///
/// The physical device reported an error while attempting the
/// operation.
///
#define RETURN_DEVICE_ERROR          ENCODE_ERROR (7)

///
/// The device can not be written to.
///
#define RETURN_WRITE_PROTECTED       ENCODE_ERROR (8)

///
/// The resource has run out.
///
#define RETURN_OUT_OF_RESOURCES      ENCODE_ERROR (9)

///
/// An inconsistency was detected on the file system causing the
/// operation to fail.
///
#define RETURN_VOLUME_CORRUPTED      ENCODE_ERROR (10)

///
/// There is no more space on the file system.
///
#define RETURN_VOLUME_FULL           ENCODE_ERROR (11)

///
/// The device does not contain any medium to perform the
/// operation.
///
#define RETURN_NO_MEDIA              ENCODE_ERROR (12)

///
/// The medium in the device has changed since the last
/// access.
///
#define RETURN_MEDIA_CHANGED         ENCODE_ERROR (13)

///
/// The item was not found.
///
#define RETURN_NOT_FOUND             ENCODE_ERROR (14)

///
/// Access was denied.
///
#define RETURN_ACCESS_DENIED         ENCODE_ERROR (15)

///
/// The server was not found or did not respond to the request.
///
#define RETURN_NO_RESPONSE           ENCODE_ERROR (16)

///
/// A mapping to the device does not exist.
///
#define RETURN_NO_MAPPING            ENCODE_ERROR (17)

///
/// A timeout time expired.
///
#define RETURN_TIMEOUT               ENCODE_ERROR (18)

///
/// The protocol has not been started.
///
#define RETURN_NOT_STARTED           ENCODE_ERROR (19)

///
/// The protocol has already been started.
///
#define RETURN_ALREADY_STARTED       ENCODE_ERROR (20)

///
/// The operation was aborted.
///
#define RETURN_ABORTED               ENCODE_ERROR (21)

///
/// An ICMP error occurred during the network operation.
///
#define RETURN_ICMP_ERROR            ENCODE_ERROR (22)

///
/// A TFTP error occurred during the network operation.
///
#define RETURN_TFTP_ERROR            ENCODE_ERROR (23)

///
/// A protocol error occurred during the network operation.
///
#define RETURN_PROTOCOL_ERROR        ENCODE_ERROR (24)

///
/// A function encountered an internal version that was
/// incompatible with a version requested by the caller.
///
#define RETURN_INCOMPATIBLE_VERSION  ENCODE_ERROR (25)

///
/// The function was not performed due to a security violation.
///
#define RETURN_SECURITY_VIOLATION    ENCODE_ERROR (26)

///
/// A CRC error was detected.
///
#define RETURN_CRC_ERROR             ENCODE_ERROR (27)

///
/// The beginning or end of media was reached.
///
#define RETURN_END_OF_MEDIA          ENCODE_ERROR (28)

///
/// The end of the file was reached.
///
#define RETURN_END_OF_FILE           ENCODE_ERROR (31)

///
/// The language specified was invalid.
///
#define RETURN_INVALID_LANGUAGE      ENCODE_ERROR (32)

///
/// The security status of the data is unknown or compromised
/// and the data must be updated or replaced to restore a valid
/// security status.
///
#define RETURN_COMPROMISED_DATA      ENCODE_ERROR (33)

///
/// Enumeration of EFI_STATUS.
///@{ 
#define EFI_SUCCESS               RETURN_SUCCESS              
#define EFI_LOAD_ERROR            RETURN_LOAD_ERROR           
#define EFI_INVALID_PARAMETER     RETURN_INVALID_PARAMETER    
#define EFI_UNSUPPORTED           RETURN_UNSUPPORTED          
#define EFI_BAD_BUFFER_SIZE       RETURN_BAD_BUFFER_SIZE      
#define EFI_BUFFER_TOO_SMALL      RETURN_BUFFER_TOO_SMALL     
#define EFI_NOT_READY             RETURN_NOT_READY            
#define EFI_DEVICE_ERROR          RETURN_DEVICE_ERROR         
#define EFI_WRITE_PROTECTED       RETURN_WRITE_PROTECTED      
#define EFI_OUT_OF_RESOURCES      RETURN_OUT_OF_RESOURCES     
#define EFI_VOLUME_CORRUPTED      RETURN_VOLUME_CORRUPTED     
#define EFI_VOLUME_FULL           RETURN_VOLUME_FULL          
#define EFI_NO_MEDIA              RETURN_NO_MEDIA             
#define EFI_MEDIA_CHANGED         RETURN_MEDIA_CHANGED        
#define EFI_NOT_FOUND             RETURN_NOT_FOUND            
#define EFI_ACCESS_DENIED         RETURN_ACCESS_DENIED        
#define EFI_NO_RESPONSE           RETURN_NO_RESPONSE          
#define EFI_NO_MAPPING            RETURN_NO_MAPPING           
#define EFI_TIMEOUT               RETURN_TIMEOUT              
#define EFI_NOT_STARTED           RETURN_NOT_STARTED          
#define EFI_ALREADY_STARTED       RETURN_ALREADY_STARTED      
#define EFI_ABORTED               RETURN_ABORTED              
#define EFI_ICMP_ERROR            RETURN_ICMP_ERROR           
#define EFI_TFTP_ERROR            RETURN_TFTP_ERROR           
#define EFI_PROTOCOL_ERROR        RETURN_PROTOCOL_ERROR       
#define EFI_INCOMPATIBLE_VERSION  RETURN_INCOMPATIBLE_VERSION 
#define EFI_SECURITY_VIOLATION    RETURN_SECURITY_VIOLATION   
#define EFI_CRC_ERROR             RETURN_CRC_ERROR   
#define EFI_END_OF_MEDIA          RETURN_END_OF_MEDIA
#define EFI_END_OF_FILE           RETURN_END_OF_FILE
#define EFI_INVALID_LANGUAGE      RETURN_INVALID_LANGUAGE
#define EFI_COMPROMISED_DATA      RETURN_COMPROMISED_DATA

#define EFI_WARN_UNKNOWN_GLYPH    RETURN_WARN_UNKNOWN_GLYPH   
#define EFI_WARN_DELETE_FAILURE   RETURN_WARN_DELETE_FAILURE  
#define EFI_WARN_WRITE_FAILURE    RETURN_WARN_WRITE_FAILURE   
#define EFI_WARN_BUFFER_TOO_SMALL RETURN_WARN_BUFFER_TOO_SMALL
#define EFI_WARN_STALE_DATA       RETURN_WARN_STALE_DATA
///@}

#define StrLen wcslen
#define StrCmp wcscmp
#define CopyMem(Dest, Src, Len) memcpy(Dest, Src, (size_t)Len)
#define CompareMem(Dest, Src, Len) memcmp(Dest, Src, (size_t)Len)
#define ZeroMem(Dest, Len) memset(Dest, 0u, (size_t)Len)

#define StrCpy wcscpy
#define StrnCpy(Dest, Src, Len) wcsncpy(Dest, Src, (size_t)Len)
#define StrnCat(Dest, Src, Len) wcsncat(Dest, Src, (size_t)Len)
#define StrnCmp(Str1, Str2, Len) wcsncmp(Str1, Str2, (size_t)Len) 

#define StrSize(Str) (2 * (wcslen ((Str)) + 1))

#define StrCat(Dest, Src) wcscat(Dest, Src)
// This macro provides an expression of the number of element in an array. It can only
// be used on an array that is allocated with [] and has a known size.
#define NUM_ELEMENTS(array) (sizeof(array) / sizeof((array)[0]))

typedef EFI_STATUS (*EFI_LOCATE_PROTOCOL)(EFI_GUID* Protocol, VOID* Handle, VOID** Interface);

///
/// EFI Boot Services Table.
///
typedef struct {
  /////
  ///// The table header for the EFI Boot Services Table.
  /////
  //EFI_TABLE_HEADER                Hdr;

  ////
  //// Task Priority Services
  ////
  //EFI_RAISE_TPL                   RaiseTPL;
  //EFI_RESTORE_TPL                 RestoreTPL;

  ////
  //// Memory Services
  ////
  //EFI_ALLOCATE_PAGES              AllocatePages;
  //EFI_FREE_PAGES                  FreePages;
  //EFI_GET_MEMORY_MAP              GetMemoryMap;
  //EFI_ALLOCATE_POOL               AllocatePool;
  //EFI_FREE_POOL                   FreePool;

  ////
  //// Event & Timer Services
  ////
  //EFI_CREATE_EVENT                  CreateEvent;
  //EFI_SET_TIMER                     SetTimer;
  //EFI_WAIT_FOR_EVENT                WaitForEvent;
  //EFI_SIGNAL_EVENT                  SignalEvent;
  //EFI_CLOSE_EVENT                   CloseEvent;
  //EFI_CHECK_EVENT                   CheckEvent;

  ////
  //// Protocol Handler Services
  ////
  //EFI_INSTALL_PROTOCOL_INTERFACE    InstallProtocolInterface;
  //EFI_REINSTALL_PROTOCOL_INTERFACE  ReinstallProtocolInterface;
  //EFI_UNINSTALL_PROTOCOL_INTERFACE  UninstallProtocolInterface;
  //EFI_HANDLE_PROTOCOL               HandleProtocol;
  //VOID                              *Reserved;
  //EFI_REGISTER_PROTOCOL_NOTIFY      RegisterProtocolNotify;
  //EFI_LOCATE_HANDLE                 LocateHandle;
  //EFI_LOCATE_DEVICE_PATH            LocateDevicePath;
  //EFI_INSTALL_CONFIGURATION_TABLE   InstallConfigurationTable;

  ////
  //// Image Services
  ////
  //EFI_IMAGE_LOAD                    LoadImage;
  //EFI_IMAGE_START                   StartImage;
  //EFI_EXIT                          Exit;
  //EFI_IMAGE_UNLOAD                  UnloadImage;
  //EFI_EXIT_BOOT_SERVICES            ExitBootServices;

  ////
  //// Miscellaneous Services
  ////
  //EFI_GET_NEXT_MONOTONIC_COUNT      GetNextMonotonicCount;
  //EFI_STALL                         Stall;
  //EFI_SET_WATCHDOG_TIMER            SetWatchdogTimer;

  ////
  //// DriverSupport Services
  ////
  //EFI_CONNECT_CONTROLLER            ConnectController;
  //EFI_DISCONNECT_CONTROLLER         DisconnectController;

  ////
  //// Open and Close Protocol Services
  ////
  //EFI_OPEN_PROTOCOL                 OpenProtocol;
  //EFI_CLOSE_PROTOCOL                CloseProtocol;
  //EFI_OPEN_PROTOCOL_INFORMATION     OpenProtocolInformation;

  ////
  //// Library Services
  ////
  //EFI_PROTOCOLS_PER_HANDLE          ProtocolsPerHandle;
  //EFI_LOCATE_HANDLE_BUFFER          LocateHandleBuffer;
  EFI_LOCATE_PROTOCOL               LocateProtocol;
  //EFI_INSTALL_MULTIPLE_PROTOCOL_INTERFACES    InstallMultipleProtocolInterfaces;
  //EFI_UNINSTALL_MULTIPLE_PROTOCOL_INTERFACES  UninstallMultipleProtocolInterfaces;

  ////
  //// 32-bit CRC Services
  ////
  //EFI_CALCULATE_CRC32               CalculateCrc32;

  ////
  //// Miscellaneous Services
  ////
  //EFI_COPY_MEM                      CopyMem;
  //EFI_SET_MEM                       SetMem;
  //EFI_CREATE_EVENT_EX               CreateEventEx;
} EFI_BOOT_SERVICES;

#endif
