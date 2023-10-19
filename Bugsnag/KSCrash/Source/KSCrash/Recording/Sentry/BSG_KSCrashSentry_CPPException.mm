//
//  BSG_KSCrashSentry_CPPException.c
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <Foundation/Foundation.h>

#include "BSGDefines.h"
#include "BSG_KSCrashC.h"
#include "BSG_KSCrashSentry_CPPException.h"
#include "BSG_KSCrashSentry_Private.h"
#include "BSG_KSCrashStringConversion.h"
#include "BSG_KSMach.h"

//#define BSG_KSLogger_LocalLevel TRACE
#include "BSG_KSLogger.h"

#include <cxxabi.h>
#include <dlfcn.h>
#include <exception>
#include <execinfo.h>
#include <typeinfo>

#define STACKTRACE_BUFFER_LENGTH 30
#define DESCRIPTION_BUFFER_LENGTH 1000

// Compiler hints for "if" statements
#define unlikely_if(x) if (__builtin_expect(x, 0))

#ifdef __cplusplus
extern "C" {
#endif
// Internal NSException recorder
bool bsg_kscrashsentry_isNSExceptionHandlerInstalled(void);
void bsg_recordException(NSException *exception);
#ifdef __cplusplus
}
#endif

// ============================================================================
#pragma mark - Globals -
// ============================================================================

/** True if this handler has been installed. */
static volatile sig_atomic_t bsg_g_installed = 0;

/** True if the handler should capture the next stack trace. */
static bool bsg_g_captureNextStackTrace = false;

static std::terminate_handler bsg_g_originalTerminateHandler;

/** Buffer for the backtrace of the most recent exception. */
static uintptr_t bsg_g_stackTrace[STACKTRACE_BUFFER_LENGTH];

/** Number of backtrace entries in the most recent exception. */
static int bsg_g_stackTraceCount = 0;

/** Context to fill with crash information. */
static BSG_KSCrash_SentryContext *bsg_g_context;

// ============================================================================
#pragma mark - Callbacks -
// ============================================================================

typedef void (*cxa_throw_type)(void *, std::type_info *, void (*)(void *));

extern "C" {
void __cxa_throw(void *thrown_exception, std::type_info *tinfo,
                 void (*dest)(void *)) __attribute__((weak));

void __cxa_throw(void *thrown_exception, std::type_info *tinfo,
                 void (*dest)(void *)) {
    BSG_KSLOG_DEBUG("### __cxa_throw 1");
    if (bsg_g_captureNextStackTrace) {
        BSG_KSLOG_DEBUG("### __cxa_throw 2");
        bsg_g_stackTraceCount =
            backtrace((void **)bsg_g_stackTrace,
                      sizeof(bsg_g_stackTrace) / sizeof(*bsg_g_stackTrace));
    }

    BSG_KSLOG_DEBUG("### __cxa_throw 3");
    static cxa_throw_type orig_cxa_throw = NULL;
    BSG_KSLOG_DEBUG("### __cxa_throw 4");
    unlikely_if(orig_cxa_throw == NULL) {
        BSG_KSLOG_DEBUG("### __cxa_throw 5");
        orig_cxa_throw = (cxa_throw_type)dlsym(RTLD_NEXT, "__cxa_throw");
        BSG_KSLOG_DEBUG("### __cxa_throw 6");
    }
    BSG_KSLOG_DEBUG("### __cxa_throw 7");
    orig_cxa_throw(thrown_exception, tinfo, dest);
    BSG_KSLOG_DEBUG("### __cxa_throw 8");
    __builtin_unreachable();
}
}

static void CPPExceptionTerminate(void) {
    BSG_KSLOG_DEBUG("### CPPExceptionTerminate 1");
    BSG_KSLOG_DEBUG("Trapped c++ exception");

    char descriptionBuff[DESCRIPTION_BUFFER_LENGTH];
    const char *name = NULL;
    const char *crashReason = NULL;

    BSG_KSLOG_DEBUG("### CPPExceptionTerminate 2");
    BSG_KSLOG_DEBUG("Get exception type name.");
    std::type_info *tinfo = __cxxabiv1::__cxa_current_exception_type();
    BSG_KSLOG_DEBUG("### CPPExceptionTerminate 3");
    if (tinfo != NULL) {
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 4: %p", tinfo);
        name = tinfo->name();
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 5");
    } else {
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 6");
        name = "std::terminate";
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 7");
        crashReason = "throw may have been called without an exception";
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 8");
        if (!bsg_g_stackTraceCount) {
            BSG_KSLOG_DEBUG("### CPPExceptionTerminate 9");
            BSG_KSLOG_DEBUG("No exception backtrace");
            bsg_g_stackTraceCount =
            backtrace((void **)bsg_g_stackTrace,
                      sizeof(bsg_g_stackTrace) / sizeof(*bsg_g_stackTrace));
            BSG_KSLOG_DEBUG("### CPPExceptionTerminate 10");
        }
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 11");
        goto after_rethrow; // Using goto to avoid indenting code below
    }

    BSG_KSLOG_DEBUG("### CPPExceptionTerminate 12");
    BSG_KSLOG_DEBUG("Discovering what kind of exception was thrown.");
    bsg_g_captureNextStackTrace = false;
    BSG_KSLOG_DEBUG("### CPPExceptionTerminate 13");
    try {
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 14");
        throw;
    } catch (NSException *exception) {
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 15");
        if (bsg_g_originalTerminateHandler != NULL) {
            BSG_KSLOG_DEBUG("### CPPExceptionTerminate 16");
            BSG_KSLOG_DEBUG("Detected NSException. Passing to the current NSException handler.");
            BSG_KSLOG_DEBUG("### CPPExceptionTerminate 17");
            bsg_g_originalTerminateHandler();
            BSG_KSLOG_DEBUG("### CPPExceptionTerminate 18");
        } else {
            BSG_KSLOG_DEBUG("Detected NSException, but there was no original C++ terminate handler.");
        }
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 19");
        return;
    } catch (std::exception &exc) {
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 20");
        strlcpy(descriptionBuff, exc.what(), sizeof(descriptionBuff));
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 21");
        crashReason = descriptionBuff;
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 22");
    } catch (std::exception *exc) {
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 23");
        strlcpy(descriptionBuff, exc->what(), sizeof(descriptionBuff));
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 24");
        crashReason = descriptionBuff;
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 25");
    }
#define CATCH_INT(TYPE)                                           \
    catch (TYPE value) {                                          \
        bsg_int64_to_string(value, descriptionBuff);              \
        crashReason = descriptionBuff;                            \
    }
#define CATCH_UINT(TYPE)                                          \
    catch (TYPE value) {                                          \
        bsg_uint64_to_string(value, descriptionBuff);             \
        crashReason = descriptionBuff;                            \
    }
#define CATCH_DOUBLE(TYPE)                                        \
    catch (TYPE value) {                                          \
        bsg_double_to_string((double)value, descriptionBuff, 16); \
        crashReason = descriptionBuff;                            \
    }
#define CATCH_STRING(TYPE)                                        \
    catch (TYPE value) {                                          \
        strncpy(descriptionBuff, value, sizeof(descriptionBuff)); \
        descriptionBuff[sizeof(descriptionBuff)-1] = 0;           \
        crashReason = descriptionBuff;                            \
    }

    CATCH_INT(char)
    CATCH_INT(short)
    CATCH_INT(int)
    CATCH_INT(long)
    CATCH_INT(long long)
    CATCH_UINT(unsigned char)
    CATCH_UINT(unsigned short)
    CATCH_UINT(unsigned int)
    CATCH_UINT(unsigned long)
    CATCH_UINT(unsigned long long)
    CATCH_DOUBLE(float)
    CATCH_DOUBLE(double)
    CATCH_DOUBLE(long double)
    CATCH_STRING(char *)
    catch (...) {
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 26");
    }

after_rethrow:
    BSG_KSLOG_DEBUG("### CPPExceptionTerminate 27");
    bsg_g_captureNextStackTrace = (bsg_g_installed != 0);

    BSG_KSLOG_DEBUG("### CPPExceptionTerminate 28");
    if (bsg_kscrashsentry_beginHandlingCrash(bsg_ksmachthread_self())) {
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 29");

#if BSG_HAVE_MACH_THREADS
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 30");
        BSG_KSLOG_DEBUG("Suspending all threads.");
        bsg_kscrashsentry_suspendThreads();
#else
        // We still need the threads list for other purposes:
        // - Stack traces
        // - Thread names
        // - Thread states
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 31");
        bsg_g_context->allThreads = bsg_ksmachgetAllThreads(&bsg_g_context->allThreadsCount);
#endif

        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 32");
        bsg_g_context->crashType = BSG_KSCrashTypeCPPException;
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 33");
        bsg_g_context->registersAreValid = false;
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 34");
        bsg_g_context->stackTrace =
            bsg_g_stackTrace + 1; // Don't record __cxa_throw stack entry
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 35");
        bsg_g_context->stackTraceLength = bsg_g_stackTraceCount - 1;
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 36");
        bsg_g_context->CPPException.name = name;
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 37");
        bsg_g_context->crashReason = crashReason;

        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 38");
        BSG_KSLOG_DEBUG("Calling main crash handler.");
        bsg_g_context->onCrash(crashContext());

        BSG_KSLOG_DEBUG(
            "Crash handling complete. Restoring original handlers.");
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 39");
        bsg_kscrashsentry_uninstall((BSG_KSCrashType)BSG_KSCrashTypeAll);
#if BSG_HAVE_MACH_THREADS
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 40");
        bsg_kscrashsentry_resumeThreads();
#endif
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 41");
        bsg_kscrashsentry_endHandlingCrash();
    }
    BSG_KSLOG_DEBUG("### CPPExceptionTerminate 42");
    if (bsg_g_originalTerminateHandler != NULL) {
        BSG_KSLOG_DEBUG("### CPPExceptionTerminate 43");
        bsg_g_originalTerminateHandler();
    }
    BSG_KSLOG_DEBUG("### CPPExceptionTerminate 44");
}

// ============================================================================
#pragma mark - Public API -
// ============================================================================

extern "C" bool bsg_kscrashsentry_installCPPExceptionHandler(
    BSG_KSCrash_SentryContext *context) {
    BSG_KSLOG_DEBUG("Installing C++ exception handler.");

    if (bsg_g_installed) {
        return true;
    }
    bsg_g_installed = 1;

    bsg_g_context = context;

    bsg_g_originalTerminateHandler = std::set_terminate(CPPExceptionTerminate);
    bsg_g_captureNextStackTrace = true;
    return true;
}

extern "C" void bsg_kscrashsentry_uninstallCPPExceptionHandler(void) {
    BSG_KSLOG_DEBUG("Uninstalling C++ exception handler.");
    if (!bsg_g_installed) {
        return;
    }

    bsg_g_captureNextStackTrace = false;
    std::set_terminate(bsg_g_originalTerminateHandler);
    bsg_g_installed = 0;
}
