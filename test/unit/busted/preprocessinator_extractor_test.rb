require File.dirname(__FILE__) + '/../unit_test_helper'
require 'preprocessinator_extractor'


class PreprocessinatorExtractorTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:file_wrapper)
    @preprocessinator_extractor = PreprocessinatorExtractor.new(objects)
  end

  def teardown
  end
  
  
  should "extract base file contents from preprocessed file regardless of whitespace and formatting" do

    preprocessed_file_contents = %Q[
      # 1 blah blah blah
      #1 "/home/project/TestIcle.c" 1
      Mary
      Mary
      Quite
      Contrary
      #37 yackity shmackity
      
      # TestIcle.c
      Jack
       and
      Jill
      # 45
      
      #TestIcle.c
      
      Went up the hill
      ].left_margin(0)


    expected_extraction_contents = %Q[
      Mary
      Mary
      Quite
      Contrary
      Jack
       and
      Jill
      
      Went up the hill
      ].left_margin(0)


    @file_wrapper.expects.readlines('project/build/preprocess/TestIcle.c').returns(preprocessed_file_contents.split("\n"))

    assert_equal(
      expected_extraction_contents.strip.split("\n"),
      @preprocessinator_extractor.extract_base_file_from_preprocessed_expansion('project/build/preprocess/TestIcle.c'))
  end
  
  
  should "extract real base file contents from real preprocessed file output" do

    preprocessed_file_contents = %Q[
      # 1 "test/system/a_project/test/test_a_file.c"
      # 1 "<built-in>"
      # 1 "<command-line>"
      # 1 "test/system/a_project/test/test_a_file.c"
      # 1 "/home/svn/ceedling/vendor/unity/src/unity.h" 1





      # 1 "/usr/include/stdio.h" 1 3 4
      # 64 "/usr/include/stdio.h" 3 4
      # 1 "/usr/include/_types.h" 1 3 4
      # 27 "/usr/include/_types.h" 3 4
      # 1 "/usr/include/sys/_types.h" 1 3 4
      # 32 "/usr/include/sys/_types.h" 3 4
      # 1 "/usr/include/sys/cdefs.h" 1 3 4
      # 33 "/usr/include/sys/_types.h" 2 3 4
      # 1 "/usr/include/machine/_types.h" 1 3 4
      # 34 "/usr/include/machine/_types.h" 3 4
      # 1 "/usr/include/i386/_types.h" 1 3 4
      # 37 "/usr/include/i386/_types.h" 3 4
      typedef signed char __int8_t;



      typedef unsigned char __uint8_t;
      typedef short __int16_t;
      typedef unsigned short __uint16_t;
      typedef int __int32_t;
      typedef unsigned int __uint32_t;
      typedef long long __int64_t;
      typedef unsigned long long __uint64_t;

      typedef long __darwin_intptr_t;
      typedef unsigned int __darwin_natural_t;
      # 70 "/usr/include/i386/_types.h" 3 4
      typedef int __darwin_ct_rune_t;





      typedef union {
       char __mbstate8[128];
       long long _mbstateL;
      } __mbstate_t;

      typedef __mbstate_t __darwin_mbstate_t;


      typedef long int __darwin_ptrdiff_t;





      typedef long unsigned int __darwin_size_t;





      typedef __builtin_va_list __darwin_va_list;





      typedef int __darwin_wchar_t;




      typedef __darwin_wchar_t __darwin_rune_t;


      typedef int __darwin_wint_t;




      typedef unsigned long __darwin_clock_t;
      typedef __uint32_t __darwin_socklen_t;
      typedef long __darwin_ssize_t;
      typedef long __darwin_time_t;
      # 35 "/usr/include/machine/_types.h" 2 3 4
      # 34 "/usr/include/sys/_types.h" 2 3 4
      # 58 "/usr/include/sys/_types.h" 3 4
      struct __darwin_pthread_handler_rec
      {
       void (*__routine)(void *);
       void *__arg;
       struct __darwin_pthread_handler_rec *__next;
      };
      struct _opaque_pthread_attr_t { long __sig; char __opaque[56]; };
      struct _opaque_pthread_cond_t { long __sig; char __opaque[40]; };
      struct _opaque_pthread_condattr_t { long __sig; char __opaque[8]; };
      struct _opaque_pthread_mutex_t { long __sig; char __opaque[56]; };
      struct _opaque_pthread_mutexattr_t { long __sig; char __opaque[8]; };
      struct _opaque_pthread_once_t { long __sig; char __opaque[8]; };
      struct _opaque_pthread_rwlock_t { long __sig; char __opaque[192]; };
      struct _opaque_pthread_rwlockattr_t { long __sig; char __opaque[16]; };
      struct _opaque_pthread_t { long __sig; struct __darwin_pthread_handler_rec *__cleanup_stack; char __opaque[1168]; };
      # 94 "/usr/include/sys/_types.h" 3 4
      typedef __int64_t __darwin_blkcnt_t;
      typedef __int32_t __darwin_blksize_t;
      typedef __int32_t __darwin_dev_t;
      typedef unsigned int __darwin_fsblkcnt_t;
      typedef unsigned int __darwin_fsfilcnt_t;
      typedef __uint32_t __darwin_gid_t;
      typedef __uint32_t __darwin_id_t;
      typedef __uint64_t __darwin_ino64_t;

      typedef __darwin_ino64_t __darwin_ino_t;



      typedef __darwin_natural_t __darwin_mach_port_name_t;
      typedef __darwin_mach_port_name_t __darwin_mach_port_t;
      typedef __uint16_t __darwin_mode_t;
      typedef __int64_t __darwin_off_t;
      typedef __int32_t __darwin_pid_t;
      typedef struct _opaque_pthread_attr_t
         __darwin_pthread_attr_t;
      typedef struct _opaque_pthread_cond_t
         __darwin_pthread_cond_t;
      typedef struct _opaque_pthread_condattr_t
         __darwin_pthread_condattr_t;
      typedef unsigned long __darwin_pthread_key_t;
      typedef struct _opaque_pthread_mutex_t
         __darwin_pthread_mutex_t;
      typedef struct _opaque_pthread_mutexattr_t
         __darwin_pthread_mutexattr_t;
      typedef struct _opaque_pthread_once_t
         __darwin_pthread_once_t;
      typedef struct _opaque_pthread_rwlock_t
         __darwin_pthread_rwlock_t;
      typedef struct _opaque_pthread_rwlockattr_t
         __darwin_pthread_rwlockattr_t;
      typedef struct _opaque_pthread_t
         *__darwin_pthread_t;
      typedef __uint32_t __darwin_sigset_t;
      typedef __int32_t __darwin_suseconds_t;
      typedef __uint32_t __darwin_uid_t;
      typedef __uint32_t __darwin_useconds_t;
      typedef unsigned char __darwin_uuid_t[16];
      typedef char __darwin_uuid_string_t[37];
      # 28 "/usr/include/_types.h" 2 3 4
      # 39 "/usr/include/_types.h" 3 4
      typedef int __darwin_nl_item;
      typedef int __darwin_wctrans_t;

      typedef __uint32_t __darwin_wctype_t;
      # 65 "/usr/include/stdio.h" 2 3 4





      typedef __darwin_va_list va_list;




      typedef __darwin_off_t off_t;




      typedef __darwin_size_t size_t;






      typedef __darwin_off_t fpos_t;
      # 98 "/usr/include/stdio.h" 3 4
      struct __sbuf {
       unsigned char *_base;
       int _size;
      };


      struct __sFILEX;
      # 132 "/usr/include/stdio.h" 3 4
      typedef struct __sFILE {
       unsigned char *_p;
       int _r;
       int _w;
       short _flags;
       short _file;
       struct __sbuf _bf;
       int _lbfsize;


       void *_cookie;
       int (*_close)(void *);
       int (*_read) (void *, char *, int);
       fpos_t (*_seek) (void *, fpos_t, int);
       int (*_write)(void *, const char *, int);


       struct __sbuf _ub;
       struct __sFILEX *_extra;
       int _ur;


       unsigned char _ubuf[3];
       unsigned char _nbuf[1];


       struct __sbuf _lb;


       int _blksize;
       fpos_t _offset;
      } FILE;



      extern FILE *__stdinp;
      extern FILE *__stdoutp;
      extern FILE *__stderrp;




      # 248 "/usr/include/stdio.h" 3 4

      void clearerr(FILE *);
      int fclose(FILE *);
      int feof(FILE *);
      int ferror(FILE *);
      int fflush(FILE *);
      int fgetc(FILE *);
      int fgetpos(FILE * , fpos_t *);
      char *fgets(char * , int, FILE *);



      FILE *fopen(const char * , const char * ) __asm("_" "fopen" );

      int fprintf(FILE * , const char * , ...) ;
      int fputc(int, FILE *);
      int fputs(const char * , FILE * ) __asm("_" "fputs" );
      size_t fread(void * , size_t, size_t, FILE * );
      FILE *freopen(const char * , const char * ,
           FILE * ) __asm("_" "freopen" );
      int fscanf(FILE * , const char * , ...) ;
      int fseek(FILE *, long, int);
      int fsetpos(FILE *, const fpos_t *);
      long ftell(FILE *);
      size_t fwrite(const void * , size_t, size_t, FILE * ) __asm("_" "fwrite" );
      int getc(FILE *);
      int getchar(void);
      char *gets(char *);

      extern const int sys_nerr;
      extern const char *const sys_errlist[];

      void perror(const char *);
      int printf(const char * , ...) ;
      int putc(int, FILE *);
      int putchar(int);
      int puts(const char *);
      int remove(const char *);
      int rename (const char *, const char *);
      void rewind(FILE *);
      int scanf(const char * , ...) ;
      void setbuf(FILE * , char * );
      int setvbuf(FILE * , char * , int, size_t);
      int sprintf(char * , const char * , ...) ;
      int sscanf(const char * , const char * , ...) ;
      FILE *tmpfile(void);
      char *tmpnam(char *);
      int ungetc(int, FILE *);
      int vfprintf(FILE * , const char * , va_list) ;
      int vprintf(const char * , va_list) ;
      int vsprintf(char * , const char * , va_list) ;

      int asprintf(char **, const char *, ...) ;
      int vasprintf(char **, const char *, va_list) ;










      char *ctermid(char *);

      char *ctermid_r(char *);




      FILE *fdopen(int, const char *) __asm("_" "fdopen" );


      char *fgetln(FILE *, size_t *);

      int fileno(FILE *);
      void flockfile(FILE *);

      const char
       *fmtcheck(const char *, const char *);
      int fpurge(FILE *);

      int fseeko(FILE *, off_t, int);
      off_t ftello(FILE *);
      int ftrylockfile(FILE *);
      void funlockfile(FILE *);
      int getc_unlocked(FILE *);
      int getchar_unlocked(void);

      int getw(FILE *);

      int pclose(FILE *);



      FILE *popen(const char *, const char *) __asm("_" "popen" );

      int putc_unlocked(int, FILE *);
      int putchar_unlocked(int);

      int putw(int, FILE *);
      void setbuffer(FILE *, char *, int);
      int setlinebuf(FILE *);

      int snprintf(char * , size_t, const char * , ...) ;
      char *tempnam(const char *, const char *) __asm("_" "tempnam" );
      int vfscanf(FILE * , const char * , va_list) ;
      int vscanf(const char * , va_list) ;
      int vsnprintf(char * , size_t, const char * , va_list) ;
      int vsscanf(const char * , const char * , va_list) ;

      FILE *zopen(const char *, const char *, int);








      FILE *funopen(const void *,
        int (*)(void *, char *, int),
        int (*)(void *, const char *, int),
        fpos_t (*)(void *, fpos_t, int),
        int (*)(void *));

      # 383 "/usr/include/stdio.h" 3 4

      int __srget(FILE *);
      int __svfscanf(FILE *, const char *, va_list) ;
      int __swbuf(int, FILE *);








      static __inline int __sputc(int _c, FILE *_p) {
       if (--_p->_w >= 0 || (_p->_w >= _p->_lbfsize && (char)_c != '\n'))
        return (*_p->_p++ = _c);
       else
        return (__swbuf(_c, _p));
      }
      # 443 "/usr/include/stdio.h" 3 4
      # 1 "/usr/include/secure/_stdio.h" 1 3 4
      # 31 "/usr/include/secure/_stdio.h" 3 4
      # 1 "/usr/include/secure/_common.h" 1 3 4
      # 32 "/usr/include/secure/_stdio.h" 2 3 4
      # 42 "/usr/include/secure/_stdio.h" 3 4
      extern int __sprintf_chk (char * , int, size_t,
           const char * , ...)
        ;




      extern int __snprintf_chk (char * , size_t, int, size_t,
            const char * , ...)
        ;




      extern int __vsprintf_chk (char * , int, size_t,
            const char * , va_list)
        ;




      extern int __vsnprintf_chk (char * , size_t, int, size_t,
             const char * , va_list)
        ;
      # 444 "/usr/include/stdio.h" 2 3 4
      # 7 "/home/svn/ceedling/vendor/unity/src/unity.h" 2
      # 1 "/usr/include/setjmp.h" 1 3 4
      # 26 "/usr/include/setjmp.h" 3 4
      # 1 "/usr/include/machine/setjmp.h" 1 3 4
      # 37 "/usr/include/machine/setjmp.h" 3 4
      # 1 "/usr/include/i386/setjmp.h" 1 3 4
      # 47 "/usr/include/i386/setjmp.h" 3 4
      typedef int jmp_buf[((9 * 2) + 3 + 16)];
      typedef int sigjmp_buf[((9 * 2) + 3 + 16) + 1];
      # 65 "/usr/include/i386/setjmp.h" 3 4

      int setjmp(jmp_buf);
      void longjmp(jmp_buf, int);


      int _setjmp(jmp_buf);
      void _longjmp(jmp_buf, int);
      int sigsetjmp(sigjmp_buf, int);
      void siglongjmp(sigjmp_buf, int);



      void longjmperror(void);


      # 38 "/usr/include/machine/setjmp.h" 2 3 4
      # 27 "/usr/include/setjmp.h" 2 3 4
      # 8 "/home/svn/ceedling/vendor/unity/src/unity.h" 2
      # 23 "/home/svn/ceedling/vendor/unity/src/unity.h"
          typedef float _UF;
      # 36 "/home/svn/ceedling/vendor/unity/src/unity.h"
          typedef unsigned char _UU8;
          typedef unsigned short _UU16;
          typedef unsigned int _UU32;
          typedef signed char _US8;
          typedef signed short _US16;
          typedef signed int _US32;
      # 65 "/home/svn/ceedling/vendor/unity/src/unity.h"
      typedef void (*UnityTestFunction)(void);

      typedef enum
      {
          UNITY_DISPLAY_STYLE_INT,
          UNITY_DISPLAY_STYLE_UINT,
          UNITY_DISPLAY_STYLE_HEX8,
          UNITY_DISPLAY_STYLE_HEX16,
          UNITY_DISPLAY_STYLE_HEX32
      } UNITY_DISPLAY_STYLE_T;

      struct _Unity
      {
          const char* TestFile;
          const char* CurrentTestName;
          unsigned char NumberOfTests;
          unsigned char TestFailures;
          unsigned char TestIgnores;
          unsigned char CurrentTestFailed;
          unsigned char CurrentTestIgnored;
          jmp_buf AbortFrame;
      };

      extern struct _Unity Unity;





      void UnityBegin(void);
      void UnityEnd(void);
      void UnityConcludeTest(void);





      void UnityPrint(const char* string);
      void UnityPrintMask(const unsigned long mask, const unsigned long number);
      void UnityPrintNumberByStyle(const long number, const UNITY_DISPLAY_STYLE_T style);
      void UnityPrintNumber(const long number);
      void UnityPrintNumberUnsigned(const unsigned long number);
      void UnityPrintNumberHex(const unsigned long number, const char nibbles);
      # 117 "/home/svn/ceedling/vendor/unity/src/unity.h"
      void UnityAssertEqualNumber(const long expected,
                                  const long actual,
                                  const char* msg,
                                  const unsigned short lineNumber,
                                  const UNITY_DISPLAY_STYLE_T style);

      void UnityAssertEqualNumberUnsigned(const unsigned long expected,
                                          const unsigned long actual,
                                          const char* msg,
                                          const unsigned short lineNumber,
                                          const UNITY_DISPLAY_STYLE_T style);

      void UnityAssertEqualIntArray(const int* expected,
                                    const int* actual,
                                    const unsigned long num_elements,
                                    const char* msg,
                                    const unsigned short lineNumber,
                                    const UNITY_DISPLAY_STYLE_T style);

      void UnityAssertEqualUnsignedIntArray(const unsigned int* expected,
                                    const unsigned int* actual,
                                    const unsigned long num_elements,
                                    const char* msg,
                                    const unsigned short lineNumber,
                                    const UNITY_DISPLAY_STYLE_T style);

      void UnityAssertBits(const long mask,
                           const long expected,
                           const long actual,
                           const char* msg,
                           const unsigned short lineNumber);

      void UnityAssertEqualString(const char* expected,
                                  const char* actual,
                                  const char* msg,
                                  const unsigned short lineNumber );

      void UnityAssertEqualMemory(const void* expected,
                                  const void* actual,
                                  unsigned long length,
                                  const char* msg,
                                  const unsigned short lineNumber );

      void UnityAssertEqualMemoryArray(const void* expected,
                                       const void* actual,
                                       unsigned long length,
                                       unsigned long num_elements,
                                       const char* msg,
                                       const unsigned short lineNumber );

      void UnityAssertNumbersWithin(const long delta,
                                    const long expected,
                                    const long actual,
                                    const char* msg,
                                    const unsigned short lineNumber);

      void UnityAssertNumbersUnsignedWithin(const unsigned long delta,
                                            const unsigned long expected,
                                            const unsigned long actual,
                                            const char* msg,
                                            const unsigned short lineNumber);

      void UnityFail(const char* message, const long line);

      void UnityIgnore(const char* message, const long line);


      void UnityAssertFloatsWithin(const _UF delta,
                                   const _UF expected,
                                   const _UF actual,
                                   const char* msg,
                                   const unsigned short lineNumber);
      # 2 "test/system/a_project/test/test_a_file.c" 2
      # 1 "test/system/a_project/include/stuff.h" 1

      int subtract(int a, int b);
      # 3 "test/system/a_project/test/test_a_file.c" 2
      # 1 "test/system/a_project/build/mocks/mock_another_file.h" 1




      # 1 "test/system/a_project/include/another_file.h" 1

      unsigned int another_function(unsigned int a);
      # 6 "test/system/a_project/build/mocks/mock_another_file.h" 2

      void mock_another_file_Init(void);
      void mock_another_file_Destroy(void);
      void mock_another_file_Verify(void);




      void another_function_ExpectAndReturn(unsigned int a, unsigned int cmock_to_return);
      # 4 "test/system/a_project/test/test_a_file.c" 2
      # 1 "test/system/a_project/include/a_file.h" 1

      void a_function(void);
      # 5 "test/system/a_project/test/test_a_file.c" 2


      void setUp(void) {}
      void tearDown(void) {}


      void test_a_single_thing(void)
      {
        { Unity.TestFile="test/system/a_project/test/test_a_file.c"; UnityIgnore(("pay no attention to the test behind the curtain"), (unsigned short)13); {longjmp(Unity.AbortFrame, 1);}; };
      }

       void test_another_thing ( void )
      {
        { Unity.TestFile="test/system/a_project/test/test_a_file.c"; UnityIgnore(("pay no attention to the test behind the curtain"), (unsigned short)18); {longjmp(Unity.AbortFrame, 1);}; };
      }

      void test_some_non_void_param_stuff()
      {
        { Unity.TestFile="test/system/a_project/test/test_a_file.c"; UnityIgnore(("pay no attention to the test behind the curtain"), (unsigned short)23); {longjmp(Unity.AbortFrame, 1);}; };
      }

      void
      test_some_multiline_test_case_action
      (void)
      {
        { Unity.TestFile="test/system/a_project/test/test_a_file.c"; UnityIgnore(("pay no attention to the test behind the curtain"), (unsigned short)30); {longjmp(Unity.AbortFrame, 1);}; };
      }

      void test_success(void)
      {
       if (1) {} else {{ Unity.TestFile="test/system/a_project/test/test_a_file.c"; UnityFail((((void *)0)), (unsigned short)35); {longjmp(Unity.AbortFrame, 1);}; };};
      }
      ].left_margin(0)


    expected_extraction_contents = %Q[
      
      void setUp(void) {}
      void tearDown(void) {}


      void test_a_single_thing(void)
      {
        { Unity.TestFile="test/system/a_project/test/test_a_file.c"; UnityIgnore(("pay no attention to the test behind the curtain"), (unsigned short)13); {longjmp(Unity.AbortFrame, 1);}; };
      }

       void test_another_thing ( void )
      {
        { Unity.TestFile="test/system/a_project/test/test_a_file.c"; UnityIgnore(("pay no attention to the test behind the curtain"), (unsigned short)18); {longjmp(Unity.AbortFrame, 1);}; };
      }

      void test_some_non_void_param_stuff()
      {
        { Unity.TestFile="test/system/a_project/test/test_a_file.c"; UnityIgnore(("pay no attention to the test behind the curtain"), (unsigned short)23); {longjmp(Unity.AbortFrame, 1);}; };
      }

      void
      test_some_multiline_test_case_action
      (void)
      {
        { Unity.TestFile="test/system/a_project/test/test_a_file.c"; UnityIgnore(("pay no attention to the test behind the curtain"), (unsigned short)30); {longjmp(Unity.AbortFrame, 1);}; };
      }

      void test_success(void)
      {
       if (1) {} else {{ Unity.TestFile="test/system/a_project/test/test_a_file.c"; UnityFail((((void *)0)), (unsigned short)35); {longjmp(Unity.AbortFrame, 1);}; };};
      }
      ].left_margin(0)


    @file_wrapper.expects.readlines('project/build/preprocess/test_a_file.c').returns(preprocessed_file_contents.split("\n"))

    assert_equal(
      expected_extraction_contents.split("\n"),
      @preprocessinator_extractor.extract_base_file_from_preprocessed_expansion('project/build/preprocess/test_a_file.c'))
  end
  
end
