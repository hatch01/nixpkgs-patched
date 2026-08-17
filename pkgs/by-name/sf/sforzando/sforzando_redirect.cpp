#define _GNU_SOURCE
#include <iostream>
#include <filesystem>
#include <string>
#include <cstring>
#include <dlfcn.h>
#include <sys/stat.h>
#include <limits.h>
#include <stdarg.h>
#include <fcntl.h>

namespace fs = std::filesystem;

#define FROM_PATH "/opt/Plogue"
#define TO_PATH "@out@/opt/Plogue"

#define ZENITY_FROM "/usr/bin/zenity"
#define ZENITY_TO "@zenity@/bin/zenity"

#define KDIALOG_FROM "/usr/bin/kdialog"
#define KDIALOG_TO "@kdialog@/bin/kdialog"

#define YAD_FROM "/usr/bin/yad"
#define YAD_TO "@yad@/bin/yad"

static std::string rewrite(const std::string &path) {
    if (path.rfind(FROM_PATH, 0) == 0) {
        std::string rewritten = std::string(TO_PATH) + path.substr(strlen(FROM_PATH));
        std::cerr << "libsforzando_redirect: REWRITE " << path << " -> " << rewritten << std::endl;
        return rewritten;
    }
    if (path == ZENITY_FROM) {
        std::cerr << "libsforzando_redirect: REWRITE " << path << " -> " << ZENITY_TO << std::endl;
        return ZENITY_TO;
    }
    if (path == KDIALOG_FROM) {
        std::cerr << "libsforzando_redirect: REWRITE " << path << " -> " << KDIALOG_TO << std::endl;
        return KDIALOG_TO;
    }
    if (path == YAD_FROM) {
        std::cerr << "libsforzando_redirect: REWRITE " << path << " -> " << YAD_TO << std::endl;
        return YAD_TO;
    }
    return path;
}

static int open_needs_mode(int flags) {
#ifdef O_TMPFILE
    return (flags & O_CREAT) || (flags & O_TMPFILE) == O_TMPFILE;
#else
    return (flags & O_CREAT);
#endif
}

#define LOOKUP(name) \
    static void *orig_ptr = NULL; \
    if (!orig_ptr) { \
        orig_ptr = dlsym(RTLD_NEXT, #name); \
        if (!orig_ptr) { \
            void *libc = dlopen("libc.so.6", RTLD_LAZY); \
            if (libc) orig_ptr = dlsym(libc, #name); \
        } \
        if (!orig_ptr) { \
            std::cerr << "libsforzando_redirect error: cannot find symbol " << #name << std::endl; \
            abort(); \
        } \
    }

#define LOOKUP_CPP(mangled_name) \
    static void *orig_ptr = NULL; \
    if (!orig_ptr) { \
        orig_ptr = dlsym(RTLD_NEXT, #mangled_name); \
        if (!orig_ptr) { \
            void *libcpp = dlopen("libstdc++.so.6", RTLD_LAZY); \
            if (libcpp) orig_ptr = dlsym(libcpp, #mangled_name); \
        } \
        if (!orig_ptr) { \
            std::cerr << "libsforzando_redirect error: cannot find symbol " << #mangled_name << std::endl; \
            abort(); \
        } \
    }

extern "C" {

int open(const char *pathname, int flags, ...) {
    LOOKUP(open)
    auto *orig = (int (*)(const char *, int, ...))orig_ptr;
    std::string r_path = rewrite(pathname);
    if (open_needs_mode(flags)) {
        va_list args;
        va_start(args, flags);
        mode_t mode = va_arg(args, mode_t);
        va_end(args);
        return orig(r_path.c_str(), flags, mode);
    }
    return orig(r_path.c_str(), flags);
}

int open64(const char *pathname, int flags, ...) {
    LOOKUP(open64)
    auto *orig = (int (*)(const char *, int, ...))orig_ptr;
    std::string r_path = rewrite(pathname);
    if (open_needs_mode(flags)) {
        va_list args;
        va_start(args, flags);
        mode_t mode = va_arg(args, mode_t);
        va_end(args);
        return orig(r_path.c_str(), flags, mode);
    }
    return orig(r_path.c_str(), flags);
}

FILE *fopen(const char *pathname, const char *mode) {
    LOOKUP(fopen)
    auto *orig = (FILE *(*)(const char *, const char *))orig_ptr;
    return orig(rewrite(pathname).c_str(), mode);
}

FILE *fopen64(const char *pathname, const char *mode) {
    LOOKUP(fopen64)
    auto *orig = (FILE *(*)(const char *, const char *))orig_ptr;
    return orig(rewrite(pathname).c_str(), mode);
}

int access(const char *pathname, int mode) {
    LOOKUP(access)
    auto *orig = (int (*)(const char *, int))orig_ptr;
    return orig(rewrite(pathname).c_str(), mode);
}

int __xstat(int ver, const char *pathname, struct stat *statbuf) {
    LOOKUP(__xstat)
    auto *orig = (int (*)(int, const char *, struct stat *))orig_ptr;
    return orig(ver, rewrite(pathname).c_str(), statbuf);
}

int __xstat64(int ver, const char *pathname, void *statbuf) {
    LOOKUP(__xstat64)
    auto *orig = (int (*)(int, const char *, void *))orig_ptr;
    return orig(ver, rewrite(pathname).c_str(), statbuf);
}

int stat(const char *pathname, struct stat *statbuf) {
    LOOKUP(stat)
    auto *orig = (int (*)(const char *, struct stat *))orig_ptr;
    return orig(rewrite(pathname).c_str(), statbuf);
}

int lstat(const char *pathname, struct stat *statbuf) {
    LOOKUP(lstat)
    auto *orig = (int (*)(const char *, struct stat *))orig_ptr;
    return orig(rewrite(pathname).c_str(), statbuf);
}

#ifdef __linux__
int __lxstat(int ver, const char *pathname, struct stat *statbuf) {
    LOOKUP(__lxstat)
    auto *orig = (int (*)(int, const char *, struct stat *))orig_ptr;
    return orig(ver, rewrite(pathname).c_str(), statbuf);
}

int __lxstat64(int ver, const char *pathname, void *statbuf) {
    LOOKUP(__lxstat64)
    auto *orig = (int (*)(int, const char *, void *))orig_ptr;
    return orig(ver, rewrite(pathname).c_str(), statbuf);
}
#endif

// Intercept std::filesystem::status
fs::file_status _ZNSt10filesystem6statusERKNS_7__cxx114pathE(const fs::path &p) {
    LOOKUP_CPP(_ZNSt10filesystem6statusERKNS_7__cxx114pathE)
    auto *orig = (fs::file_status (*)(const fs::path &))orig_ptr;
    std::string path_str = p.string();
    if (path_str.rfind(FROM_PATH, 0) == 0) {
        std::string r_path = rewrite(path_str);
        return orig(fs::path(r_path));
    }
    return orig(p);
}

// Intercept std::filesystem::create_directories
bool _ZNSt10filesystem18create_directoriesERKNS_7__cxx114pathE(const fs::path &p) {
    LOOKUP_CPP(_ZNSt10filesystem18create_directoriesERKNS_7__cxx114pathE)
    auto *orig = (bool (*)(const fs::path &))orig_ptr;
    std::string path_str = p.string();
    if (path_str.rfind(FROM_PATH, 0) == 0) {
        std::string r_path = rewrite(path_str);
        return orig(fs::path(r_path));
    }
    return orig(p);
}

// Intercept std::filesystem::recursive_directory_iterator constructor
void _ZNSt10filesystem7__cxx1128recursive_directory_iteratorC1ERKNS0_4pathENS_17directory_optionsEPSt10error_code(
    void *this_ptr, const fs::path &p, int options, void *ec
) {
    LOOKUP_CPP(_ZNSt10filesystem7__cxx1128recursive_directory_iteratorC1ERKNS0_4pathENS_17directory_optionsEPSt10error_code)
    auto *orig = (void (*)(void *, const fs::path &, int, void *))orig_ptr;
    std::string path_str = p.string();
    if (path_str.rfind(FROM_PATH, 0) == 0) {
        std::string r_path = rewrite(path_str);
        orig(this_ptr, fs::path(r_path), options, ec);
        return;
    }
    orig(this_ptr, p, options, ec);
}

// Intercept std::basic_filebuf::open
void * _ZNSt13basic_filebufIcSt11char_traitsIcEE4openEPKcSt13_Ios_Openmode(void *this_ptr, const char *pathname, int openmode) {
    LOOKUP_CPP(_ZNSt13basic_filebufIcSt11char_traitsIcEE4openEPKcSt13_Ios_Openmode)
    auto *orig = (void *(*)(void *, const char *, int))orig_ptr;
    std::string path_str = pathname;
    if (path_str.rfind(FROM_PATH, 0) == 0) {
        std::string r_path = rewrite(path_str);
        return orig(this_ptr, r_path.c_str(), openmode);
    }
    return orig(this_ptr, pathname, openmode);
}

} // extern "C"
